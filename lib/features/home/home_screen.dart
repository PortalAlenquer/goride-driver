import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/config/app_theme.dart';
import '../../core/models/user_model.dart';
import '../../core/services/home_service.dart';
import '../../core/services/websocket_service.dart';
import 'widgets/home_bottom_panel.dart';
import 'widgets/home_heat_chip.dart';
import 'widgets/home_ride_request_sheet.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../main.dart';
import '../../core/config/api_client.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ── Serviços ──────────────────────────────────────────────────
  final _homeService = HomeService();
  final _ws          = WebSocketService();

  // ── Mapa ──────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Position?            _currentPosition;

  // ── Dados do motorista ────────────────────────────────────────
  UserModel?            _user;
  Map<String, dynamic>? _driverInfo;
  Map<String, dynamic>? _walletInfo;

  bool _isOnline      = false;
  bool _loading       = true;
  bool _needsVehicle  = false;
  bool _needsApproval = false;

  // ── Corrida pendente ──────────────────────────────────────────
  bool                  _hasNewRide   = false;
  bool                  _fetchingRide = false;
  int _unreadNotifications = 0;
  Map<String, dynamic>? _pendingRide;

  // ── Heatmap ───────────────────────────────────────────────────
  bool        _heatmapActive = false;
  bool        _heatLoading   = false;
  bool        _showHeat      = true;
  bool        _showSearching = true;
  bool        _showDrivers   = true;
  DateTime?   _heatLastUpdate;
  Set<Circle> _circles        = {};
  List<Map<String, dynamic>> _heatPoints    = [];
  List<Map<String, dynamic>> _searchingNow  = [];
  List<Map<String, dynamic>> _onlineDrivers = [];

  // ── Camada de corridas no mapa ────────────────────────────────
  bool        _ridesLayerActive  = false;
  bool        _ridesLayerLoading = false;
  Set<Marker> _rideMarkers       = {};
  List<Map<String, dynamic>> _mapRides = [];

  // ── Timers e streams ──────────────────────────────────────────
  Timer?                        _userTimer;
  Timer?                        _fallbackTimer;
  Timer?                        _heatTimer;
  Timer?                        _ridesTimer;
  StreamSubscription<Position>? _positionSub;

  // ─────────────────────────────────────────────────────────────
  // Ciclo de vida
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _initLocation();
    _startUserPolling();
    _listenFcm();
    _loadUnreadCount();
    
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userTimer?.cancel();
    _fallbackTimer?.cancel();
    _heatTimer?.cancel();
    _ridesTimer?.cancel();
    _positionSub?.cancel();
    _mapController?.dispose();
    _ws.off('ride.requested');
    _ws.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _userTimer?.cancel();
      _fallbackTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startUserPolling();
      if (_isOnline && !_hasNewRide) _startWsRideListener();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FCM — foreground
  // ─────────────────────────────────────────────────────────────

void _listenFcm() {
  FirebaseMessaging.onMessage.listen((message) async {
    if (!mounted) return;

     // Atualiza badge de avisos
    _loadUnreadCount();
    
    // Exibe notificação local para QUALQUER mensagem em foreground
    await localNotifications.show(
      100,
      message.notification?.title ?? '📢 Aviso GoRide',
      message.notification?.body  ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goride_rides',
          'Corridas GoRide',
          channelDescription: 'Notificações de novas corridas',
          importance:         Importance.max,
          priority:           Priority.high,
          playSound:          true,
          enableVibration:    true,
          icon:               '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
    );

       // Se for corrida nova, exibe o sheet
    if (_isOnline && !_hasNewRide && message.data['type'] == 'new_ride') {
      await _fetchAndShowRide(rideId: message.data['ride_id']);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    if (!mounted) return;
    _loadUnreadCount();
    if (message.data['type'] == 'new_ride') {
      _fetchAndShowRide(rideId: message.data['ride_id']);
    }
  });
}
  // ─────────────────────────────────────────────────────────────
  // Polling usuário — 60s
  // ─────────────────────────────────────────────────────────────

  void _startUserPolling() {
  _userTimer?.cancel();
  _userTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    if (!mounted) return;
    await _loadUser();
    await _loadUnreadCount();
  });
}

Future<void> _loadUnreadCount() async {
  try {
    final res = await ApiClient().dio.get('/notifications');
    if (!mounted) return;
    setState(() => _unreadNotifications = res.data['unread_count'] ?? 0);
  } catch (_) {}
}

  // ─────────────────────────────────────────────────────────────
  // WebSocket — canal público 'rides'
  // ─────────────────────────────────────────────────────────────

  Future<void> _startWsRideListener() async {
    _ws.off('ride.requested');
    await _ws.connect();
    await _ws.subscribeToPublic('rides');

    _ws.on('ride.requested', (payload) async {
      if (!mounted || !_isOnline || _hasNewRide) return;
      await _fetchAndShowRide(
        rideId:          payload['ride_id']?.toString() ?? payload['id']?.toString(),
        fallbackPayload: payload,
      );
    });

    // Fallback poll — 30s
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted || !_isOnline || _hasNewRide) return;
      await _fetchAndShowRide();
    });
  }

  void _stopWsRideListener() {
    _ws.off('ride.requested');
    _fallbackTimer?.cancel();
  }

  // ─────────────────────────────────────────────────────────────
  // Busca corrida e exibe sheet
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchAndShowRide({
    String? rideId,
    Map<String, dynamic>? fallbackPayload,
  }) async {
    if (_hasNewRide || _fetchingRide || !mounted) return;
    _fetchingRide = true;

    try {
      final rides = await _homeService.getPendingRides();
      if (rides.isEmpty || !mounted || _hasNewRide) return;

      Map<String, dynamic> rideData;
      if (rideId != null) {
        rideData = rides.firstWhere(
          (r) => r['id']?.toString() == rideId,
          orElse: () => rides.first,
        );
      } else {
        rideData = rides.first;
      }

      if (!mounted || _hasNewRide) return;
      setState(() { _hasNewRide = true; _pendingRide = rideData; });
      await _notifyNewRide();
      if (mounted) _showRideRequest();
    } catch (_) {
      if (fallbackPayload != null && mounted && !_hasNewRide) {
        final partial = {
          'id':                  fallbackPayload['ride_id'] ?? '',
          'estimated_price':     fallbackPayload['estimated_price'] ?? 0.0,
          'distance_km':         fallbackPayload['distance_km'],
          'duration_minutes':    fallbackPayload['duration_minutes'],
          'origin_address':      fallbackPayload['origin_address'],
          'destination_address': fallbackPayload['destination_address'],
          'payment_method':      fallbackPayload['payment_method'],
          'fee_type':            'fixed',
          'fee_value':           0.0,
        };
        setState(() { _hasNewRide = true; _pendingRide = partial; });
        await _notifyNewRide();
        if (mounted) _showRideRequest();
      }
    } finally {
      _fetchingRide = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Localização
  // ─────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _onPositionUpdate(initial);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy:       LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen(_onPositionUpdate);
    } catch (_) {}
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    setState(() => _currentPosition = position);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(position.latitude, position.longitude), 15,
    ));
    if (_isOnline) _homeService.updateLocation(position);
  }

  // ─────────────────────────────────────────────────────────────
  // Dados do motorista
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    try {
      final data = await _homeService.loadDriverData();
      if (!mounted) return;
      setState(() {
        _user          = data['user']          as UserModel;
        _driverInfo    = data['driver']        as Map<String, dynamic>?;
        _walletInfo    = data['wallet']        as Map<String, dynamic>?;
        _needsVehicle  = data['needsVehicle']  as bool;
        _needsApproval = data['needsApproval'] as bool;
        _isOnline      = data['isOnline']      as bool;
        _loading       = false;
      });

      if (_isOnline) await _startWsRideListener();

      final activeRideId = await _homeService.checkActiveRide();
      if (activeRideId != null && mounted) {
        context.go('/ride-detail/$activeRideId');
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Toggle online / offline
  // ─────────────────────────────────────────────────────────────

  Future<void> _toggleOnline() async {
    if (!_isOnline) {
      if (_needsVehicle) {
        _showSnack('Adicione seu veículo antes de ficar online.', AppTheme.warning);
        return;
      }
      if (_needsApproval) {
        _showSnack('Aguarde a aprovação do seu cadastro.', AppTheme.warning);
        return;
      }
    }
    try {
      await _homeService.setOnlineStatus(!_isOnline);
      setState(() => _isOnline = !_isOnline);
      if (_isOnline) {
        if (_currentPosition != null) {
          await _homeService.updateLocation(_currentPosition!);
        }
        await _startWsRideListener();
      } else {
        _stopWsRideListener();
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Sheet de corrida
  // ─────────────────────────────────────────────────────────────

  Future<void> _notifyNewRide() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  void _showRideRequest() {
    if (_pendingRide == null) return;
    showModalBottomSheet(
      context:       context,
      isDismissible: false,
      enableDrag:    false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HomeRideRequestSheet(
        ride:           _pendingRide!,
        timeoutSeconds: 20,
        onAccept: () {
          final rideId = _pendingRide!['id']?.toString() ?? '';
          _acceptRide(rideId);
        },
        onReject: () async {
          final rideId = _pendingRide?['id']?.toString();
          if (rideId != null && rideId.isNotEmpty) {
            try { await _homeService.rejectRide(rideId); } catch (_) {}
          }
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() { _hasNewRide = false; _pendingRide = null; });
    });
  }

  Future<void> _acceptRide(String rideId) async {
    try {
      await _homeService.acceptRide(rideId);
      if (mounted) context.go('/ride-detail/$rideId');
    } catch (_) {
      if (mounted) _showSnack('Erro ao aceitar corrida.', AppTheme.danger);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Heatmap
  // ─────────────────────────────────────────────────────────────

  Future<void> _toggleHeatmap() async {
    if (_heatmapActive) {
      _heatTimer?.cancel();
      setState(() { _heatmapActive = false; _circles = {}; });
      return;
    }
    setState(() => _heatLoading = true);
    await _fetchHeatmapData();
    setState(() { _heatmapActive = true; _heatLoading = false; });
    _startHeatRefresh();
  }

  Future<void> _fetchHeatmapData() async {
    try {
      final data     = await _homeService.getMapData();
      _heatPoints    = data['heat_points']!;
      _searchingNow  = data['searching_now']!;
      _onlineDrivers = data['online_drivers']!;
      _heatLastUpdate = DateTime.now();
      _buildCircles();
    } catch (_) {}
  }

  void _buildCircles() {
    final circles = <Circle>{};
    int i = 0;

    if (_showHeat) {
      for (final p in _heatPoints) {
        final weight = (p['weight'] as num?)?.toDouble() ?? 0.5;
        circles.add(Circle(
          circleId:  CircleId('heat_$i'),
          center:    LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
          radius:    180,
          fillColor: Color.lerp(
            Colors.orange.withValues(alpha: 0.15),
            Colors.red.withValues(alpha: 0.45),
            weight,
          )!,
          strokeWidth: 0,
        ));
        i++;
      }
    }

    if (_showSearching) {
      for (final p in _searchingNow) {
        final ll = LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
        circles.add(Circle(
          circleId:    CircleId('s_outer_$i'),
          center:      ll, radius: 300,
          fillColor:   Colors.green.withValues(alpha: 0.12),
          strokeColor: Colors.green.withValues(alpha: 0.3),
          strokeWidth: 1,
        ));
        circles.add(Circle(
          circleId:    CircleId('s_inner_$i'),
          center:      ll, radius: 100,
          fillColor:   Colors.green.withValues(alpha: 0.5),
          strokeWidth: 0,
        ));
        i++;
      }
    }

    if (_showDrivers) {
      for (final p in _onlineDrivers) {
        circles.add(Circle(
          circleId:    CircleId('driver_$i'),
          center:      LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
          radius:      80,
          fillColor:   Colors.blue.withValues(alpha: 0.35),
          strokeColor: Colors.blue.withValues(alpha: 0.6),
          strokeWidth: 1,
        ));
        i++;
      }
    }

    if (mounted) setState(() => _circles = circles);
  }

  void _startHeatRefresh() {
    _heatTimer?.cancel();
    _heatTimer = Timer.periodic(const Duration(seconds: 120), (_) async {
      if (!mounted || !_heatmapActive) { _heatTimer?.cancel(); return; }
      await _fetchHeatmapData();
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Camada de corridas no mapa
  // ─────────────────────────────────────────────────────────────

  Future<void> _toggleRidesLayer() async {
    if (_ridesLayerActive) {
      _ridesTimer?.cancel();
      setState(() { _ridesLayerActive = false; _rideMarkers = {}; _mapRides = []; });
      return;
    }
    setState(() => _ridesLayerLoading = true);
    await _fetchRidesLayer();
    setState(() { _ridesLayerActive = true; _ridesLayerLoading = false; });
    _startRidesLayerRefresh();
  }

  Future<void> _fetchRidesLayer() async {
    try {
      final data = await _homeService.getMapData();
      _mapRides = data['searching_now']!;
      _buildRideMarkers();
    } catch (_) {}
  }

  void _buildRideMarkers() {
    final markers = <Marker>{};
    for (final ride in _mapRides) {
      final lat = (ride['lat'] as num).toDouble();
      final lng = (ride['lng'] as num).toDouble();
      markers.add(Marker(
        markerId: MarkerId('ride_${ride['id']}'),
        position: LatLng(lat, lng),
        icon:     BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap:    () => _showMapRideSheet(ride),
      ));
    }
    if (mounted) setState(() => _rideMarkers = markers);
  }

  void _startRidesLayerRefresh() {
    _ridesTimer?.cancel();
    _ridesTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!mounted || !_ridesLayerActive) { _ridesTimer?.cancel(); return; }
      await _fetchRidesLayer();
    });
  }

  void _showMapRideSheet(Map<String, dynamic> ride) {
    final rideId = ride['id'].toString();
    showModalBottomSheet(
      context:       context,
      isDismissible: true,
      enableDrag:    true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HomeRideRequestSheet(
        ride:     ride,
        onAccept: () => _acceptRide(rideId),
        onReject: () async {
          try { await _homeService.rejectRide(rideId); } catch (_) {}
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() {
        _mapRides.removeWhere((r) => r['id'].toString() == rideId);
        _rideMarkers.removeWhere((m) => m.markerId.value == 'ride_$rideId');
      });
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String get _balanceLabel {
    final b = double.tryParse(_walletInfo?['balance']?.toString() ?? '0') ?? 0.0;
    return 'R\$ ${b.toStringAsFixed(2)}';
  }

  bool get _isBalanceNegative {
    final b = double.tryParse(_walletInfo?['balance']?.toString() ?? '0') ?? 0.0;
    return b < 0;
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title:   const Text('Sair do app?'),
            content: const Text('Deseja realmente fechar o aplicativo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Não'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                child: const Text('Sim, sair'),
              ),
            ],
          ),
        );
        if ((shouldExit ?? false) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [

              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null
                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : const LatLng(-15.7801, -47.9292),
                  zoom: 15,
                ),
                myLocationEnabled:       true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled:     false,
                circles:  _circles,
                markers:  _rideMarkers,
                onMapCreated: (c) => _mapController = c,
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [

                        GestureDetector(
                          onTap: () => context.go('/wallet'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(
                                color: _isBalanceNegative
                                    ? AppTheme.danger.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                              )],
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (_isBalanceNegative ? AppTheme.danger : AppTheme.secondary)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet,
                                  color: _isBalanceNegative ? AppTheme.danger : AppTheme.secondary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Saldo',
                                    style: TextStyle(fontSize: 10, color: AppTheme.gray)),
                                  Text(_balanceLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _isBalanceNegative ? AppTheme.danger : AppTheme.dark,
                                    )),
                                ],
                              ),
                            ]),
                          ),
                        ),

                        const Spacer(),

                        _MapBtn(
                          active:      _ridesLayerActive,
                          loading:     _ridesLayerLoading,
                          badge:       _ridesLayerActive ? _mapRides.length : 0,
                          onTap:       _toggleRidesLayer,
                          icon:        Icons.location_on,
                          activeColor: Colors.green.shade600,
                          iconColor:   Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),

                        _MapBtn(
                          active:      _heatmapActive,
                          loading:     _heatLoading,
                          onTap:       _toggleHeatmap,
                          icon:        Icons.local_fire_department,
                          activeColor: Colors.deepOrange,
                          iconColor:   Colors.deepOrange,
                        ),
                        const SizedBox(width: 8),

                        Stack(
  clipBehavior: Clip.none,
  children: [
    _IconBtn(
      icon:  Icons.person_outline,
      color: AppTheme.dark,
      onTap: () => context.go('/profile'),
    ),
    if (_unreadNotifications > 0)
      Positioned(
        right: -4, top: -4,
        child: Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color:  AppTheme.danger,
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Center(
            child: Text(
              _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
              style: const TextStyle(
                fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
  ],
),
                      ]),

                      if (_heatmapActive) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            HomeHeatChip(
                              label:  'Corridas hoje (${_heatPoints.length})',
                              color:  Colors.deepOrange,
                              active: _showHeat,
                              onTap:  () {
                                setState(() => _showHeat = !_showHeat);
                                _buildCircles();
                              },
                            ),
                            const SizedBox(width: 8),
                            HomeHeatChip(
                              label:  'Motoristas (${_onlineDrivers.length})',
                              color:  Colors.blue,
                              active: _showDrivers,
                              onTap:  () {
                                setState(() => _showDrivers = !_showDrivers);
                                _buildCircles();
                              },
                            ),
                            const SizedBox(width: 8),
                            if (_heatLastUpdate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                  )],
                                ),
                                child: Row(children: [
                                  const Icon(Icons.refresh, size: 12, color: AppTheme.gray),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_heatLastUpdate!.hour.toString().padLeft(2, '0')}:'
                                    '${_heatLastUpdate!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.gray),
                                  ),
                                ]),
                              ),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: HomeBottomPanel(
                  isOnline:       _isOnline,
                  needsVehicle:   _needsVehicle,
                  needsApproval:  _needsApproval,
                  rating:         _driverInfo?['rating']?.toString() ?? '5.0',
                  balanceLabel:   _balanceLabel,
                  onToggleOnline: _toggleOnline,
                ),
              ),
            ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Widgets locais
// ─────────────────────────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final bool active;
  final bool loading;
  final int badge;
  final VoidCallback onTap;
  final IconData icon;
  final Color activeColor;
  final Color iconColor;

  const _MapBtn({
    required this.active,
    required this.loading,
    this.badge = 0,
    required this.onTap,
    required this.icon,
    required this.activeColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.1), blurRadius: 8,
          )],
        ),
        child: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: active ? Colors.white : iconColor, size: 20),
                if (badge > 0)
                  Positioned(
                    right: -6, top: -6,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color:  Colors.red,
                        shape:  BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text('$badge',
                          style: const TextStyle(
                            fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold,
                          )),
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.1), blurRadius: 8,
          )],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}