import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/home_service.dart';
import 'widgets/home_bottom_panel.dart';
import 'widgets/home_heat_chip.dart';
import 'widgets/home_ride_request_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeService = HomeService();

  GoogleMapController? _mapController;
  Position?            _currentPosition;
  UserModel?           _user;
  Map<String, dynamic>? _driverInfo;
  Map<String, dynamic>? _walletInfo;

  bool _isOnline      = false;
  bool _loading       = true;
  bool _needsVehicle  = false;
  bool _needsApproval = false;

  // ── Corrida pendente ──────────────────────────────────────────
  bool                  _hasNewRide  = false;
  Map<String, dynamic>? _pendingRide;

  // ── Heatmap ───────────────────────────────────────────────────
  bool      _heatmapActive = false;
  bool      _heatLoading   = false;
  bool      _showHeat      = true;
  bool      _showSearching = true;
  bool      _showDrivers   = true;
  DateTime? _heatLastUpdate;
  Set<Circle> _circles = {};
  List<Map<String, dynamic>> _heatPoints    = [];
  List<Map<String, dynamic>> _searchingNow  = [];
  List<Map<String, dynamic>> _onlineDrivers = [];

  // ── Layer de corridas no mapa ─────────────────────────────────
  bool        _ridesLayerActive  = false;
  bool        _ridesLayerLoading = false;
  Set<Marker> _rideMarkers       = {};
  List<Map<String, dynamic>> _mapRides = [];

  // ── Timers / streams ──────────────────────────────────────────
  Timer?            _userTimer;    // dados do usuário — a cada 60s
  Timer?            _rideTimer;    // check corridas — a cada 8s
  StreamSubscription<Position>? _positionSub; // localização contínua

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initLocation();
    _startUserPolling();
    _startRidePolling();
  }

  @override
  void dispose() {
    _userTimer?.cancel();
    _rideTimer?.cancel();
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── MELHORIA 5: Polling separado ─────────────────────────────
  // Dados do usuário (rating, saldo, status) — menos urgente → 60s
  void _startUserPolling() {
    _userTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!mounted) return;
      await _loadUser();
    });
  }

  // Check de corridas pendentes — urgente → 8s, só quando online
  void _startRidePolling() {
    _rideTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!mounted) return;
      if (_isOnline) await _checkForRides();
    });
  }

  // ── MELHORIA 6: Localização contínua com positionStream ──────
  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      // Pega posição inicial uma vez
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _onPositionUpdate(initial);

      // Inicia stream contínuo — atualiza a cada 10 metros ou 5 segundos
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy:          LocationAccuracy.high,
          distanceFilter:    10,   // metros mínimos para disparar update
        ),
      ).listen(_onPositionUpdate);
    } catch (_) {}
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    setState(() => _currentPosition = position);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(position.latitude, position.longitude), 15));
    // Envia localização para o servidor apenas quando online
    if (_isOnline) {
      _homeService.updateLocation(position);
    }
  }

  // ── Carregamento de dados do motorista ────────────────────────

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

      final activeRideId = await _homeService.checkActiveRide();
if (activeRideId != null && mounted) {
  context.go('/ride-detail/$activeRideId');
  return;
}
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Toggle online ─────────────────────────────────────────────

  Future<void> _toggleOnline() async {
    if (!_isOnline) {
      if (_needsVehicle) {
        _showSnack('Adicione seu veículo antes de ficar online.',
          AppTheme.warning);
        return;
      }
      if (_needsApproval) {
        _showSnack('Aguarde a aprovação do seu cadastro.',
          AppTheme.warning);
        return;
      }
    }
    try {
      await _homeService.setOnlineStatus(!_isOnline);
      setState(() => _isOnline = !_isOnline);
      // Envia localização imediatamente ao ficar online
      if (_isOnline && _currentPosition != null) {
        await _homeService.updateLocation(_currentPosition!);
      }
    } catch (_) {}
  }

  // ── Check de corridas pendentes ───────────────────────────────

  Future<void> _checkForRides() async {
    try {
      final rides = await _homeService.getPendingRides();
      if (rides.isNotEmpty && !_hasNewRide && mounted) {
        setState(() {
          _hasNewRide  = true;
          _pendingRide = rides.first;
        });
        await _notifyNewRide(); // MELHORIA 7
        if (mounted) _showRideRequest();
      }
    } catch (_) {}
  }

  // ── MELHORIA 7: Feedback sonoro e vibração ────────────────────
  Future<void> _notifyNewRide() async {
    try {
      // Vibração: padrão curto-longo-curto (estilo notificação)
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  // ── Corridas ──────────────────────────────────────────────────

  void _showRideRequest() {
    if (_pendingRide == null) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag:    false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => HomeRideRequestSheet(
        ride: _pendingRide!,
        onAccept: () async {
          Navigator.pop(context);
          await _acceptRide(_pendingRide!['id']);
          setState(() { _hasNewRide = false; _pendingRide = null; });
        },
        onReject: () async {
          final rideId = _pendingRide!['id'];
          try { await _homeService.rejectRide(rideId); } catch (_) {}
          if (mounted) Navigator.pop(context);
          setState(() { _hasNewRide = false; _pendingRide = null; });
        },
      ),
    );
  }

  Future<void> _acceptRide(String rideId) async {
    try {
      await _homeService.acceptRide(rideId);
      if (mounted) context.go('/ride-detail/$rideId');
    } catch (_) {}
  }

  // ── Heatmap ───────────────────────────────────────────────────

  Future<void> _toggleHeatmap() async {
    if (_heatmapActive) {
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
      final data      = await _homeService.getMapData();
      _heatPoints     = data['heat_points']!;
      _searchingNow   = data['searching_now']!;
      _onlineDrivers  = data['online_drivers']!;
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
          circleId: CircleId('heat_$i'),
          center: LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble()),
          radius: 180,
          fillColor: Color.lerp(
            Colors.orange.withValues(alpha: 0.15),
            Colors.red.withValues(alpha: 0.45),
            weight)!,
          strokeWidth: 0,
        ));
        i++;
      }
    }

    if (_showSearching) {
      for (final p in _searchingNow) {
        final ll = LatLng(
          (p['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble());
        circles.add(Circle(
          circleId: CircleId('s_outer_$i'),
          center: ll, radius: 300,
          fillColor:   Colors.green.withValues(alpha: 0.12),
          strokeColor: Colors.green.withValues(alpha: 0.3),
          strokeWidth: 1,
        ));
        circles.add(Circle(
          circleId: CircleId('s_inner_$i'),
          center: ll, radius: 100,
          fillColor: Colors.green.withValues(alpha: 0.5),
          strokeWidth: 0,
        ));
        i++;
      }
    }

    if (_showDrivers) {
      for (final p in _onlineDrivers) {
        circles.add(Circle(
          circleId: CircleId('driver_$i'),
          center: LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble()),
          radius: 80,
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
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted || !_heatmapActive) return false;
      await _fetchHeatmapData();
      return true;
    });
  }

  // ── Layer de corridas no mapa ─────────────────────────────────

  Future<void> _toggleRidesLayer() async {
    if (_ridesLayerActive) {
      setState(() {
        _ridesLayerActive = false;
        _rideMarkers      = {};
        _mapRides         = [];
      });
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
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen),
        onTap: () => _showMapRideSheet(ride),
      ));
    }
    if (mounted) setState(() => _rideMarkers = markers);
  }

  void _startRidesLayerRefresh() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 15));
      if (!mounted || !_ridesLayerActive) return false;
      await _fetchRidesLayer();
      return true;
    });
  }

  void _showMapRideSheet(Map<String, dynamic> ride) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag:    true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => HomeRideRequestSheet(
        ride: ride,
        onAccept: () async {
          Navigator.pop(context);
          await _acceptRide(ride['id']);
        },
        onReject: () async {
          final rideId = ride['id'];
          try { await _homeService.rejectRide(rideId); } catch (_) {}
          if (mounted) Navigator.pop(context);
          setState(() {
            _mapRides.removeWhere((r) => r['id'] == rideId);
            _rideMarkers.removeWhere(
              (m) => m.markerId.value == 'ride_$rideId');
          });
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color));
  }

  String get _balanceLabel {
    final b = double.tryParse(
      _walletInfo?['balance']?.toString() ?? '0') ?? 0.0;
    return 'R\$ ${b.toStringAsFixed(2)}';
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Stack(children: [

            // ── Mapa ─────────────────────────────────────────
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude,
                           _currentPosition!.longitude)
                  : const LatLng(-15.7801, -47.9292),
                zoom: 15,
              ),
              myLocationEnabled:       true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled:     false,
              circles:  _circles,
              markers:  _rideMarkers,
              onMapCreated: (c) {
                _mapController = c;
                if (_currentPosition != null) {
                  c.animateCamera(CameraUpdate.newLatLngZoom(
                    LatLng(_currentPosition!.latitude,
                           _currentPosition!.longitude), 15));
                }
              },
            ),

            // ── Header ───────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [

                      // Avatar + nome
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8)],
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                              AppTheme.secondary.withValues(alpha: 0.1),
                            child: Text(
                              (_user?.name ?? 'M')[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _user?.name?.split(' ').first ?? 'Motorista',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                        ]),
                      ),

                      const Spacer(),

                      // Botão corridas no mapa
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

                      // Botão heatmap
                      _MapBtn(
                        active:      _heatmapActive,
                        loading:     _heatLoading,
                        onTap:       _toggleHeatmap,
                        icon:        Icons.local_fire_department,
                        activeColor: Colors.deepOrange,
                        iconColor:   Colors.deepOrange,
                      ),
                      const SizedBox(width: 8),

                      // Perfil
                      _IconBtn(
                        icon:  Icons.person_outline,
                        color: AppTheme.dark,
                        onTap: () => context.go('/profile'),
                      ),
                      const SizedBox(width: 8),

                      // Logout
                      _IconBtn(
                        icon:  Icons.logout,
                        color: AppTheme.danger,
                        onTap: () async {
                          final router = GoRouter.of(context);
                          await AuthService().logout();
                          router.go('/login');
                        },
                      ),
                    ]),

                    // Filtros heatmap
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
                            label:  'Buscando (${_searchingNow.length})',
                            color:  Colors.green,
                            active: _showSearching,
                            onTap:  () {
                              setState(() =>
                                _showSearching = !_showSearching);
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4)],
                              ),
                              child: Row(children: [
                                const Icon(Icons.refresh,
                                  size: 12, color: AppTheme.gray),
                                const SizedBox(width: 4),
                                Text(
                                  '${_heatLastUpdate!.hour.toString().padLeft(2, '0')}:'
                                  '${_heatLastUpdate!.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 11, color: AppTheme.gray)),
                              ]),
                            ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Painel inferior ───────────────────────────────
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
    );
  }
}

// ── Botão do mapa com badge e loading ────────────────────────────

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
            color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                  color: active ? Colors.white : iconColor, size: 20),
                if (badge > 0)
                  Positioned(
                    right: -6, top: -6,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white, width: 1.5)),
                      child: Center(
                        child: Text('$badge',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}

// ── Botão ícone simples ───────────────────────────────────────────

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
            color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}