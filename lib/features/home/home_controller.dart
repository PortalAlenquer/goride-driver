import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/config/api_client.dart';
import '../../core/models/user_model.dart';
import '../../core/services/home_service.dart';
import '../../core/services/websocket_service.dart';
import '../../main.dart';

class HomeController extends ChangeNotifier {
  HomeController() {
    _init();
  }

  // ── Serviços ──────────────────────────────────────────────────
  final homeService = HomeService();
  final ws          = WebSocketService();

  // ── Mapa ──────────────────────────────────────────────────────
  GoogleMapController? mapController;
  Position?            currentPosition;

  // ── Dados do motorista ────────────────────────────────────────
  UserModel?            user;
  Map<String, dynamic>? driverInfo;
  Map<String, dynamic>? walletInfo;

  bool isOnline      = false;
  bool loading       = true;
  bool needsVehicle  = false;
  bool needsApproval = false;

  // ── Tipos de serviço do motorista ─────────────────────────────
  List<String> serviceTypes = ['ride'];
  bool get acceptsDelivery => serviceTypes.contains('delivery');

  // ── Corrida/entrega pendente ──────────────────────────────────
  bool                  hasNewRide    = false;
  bool                  fetchingRide  = false;
  Map<String, dynamic>? pendingRide;

  // ── Notificações ──────────────────────────────────────────────
  int unreadNotifications = 0;

  // ── Camadas do mapa ───────────────────────────────────────────
  bool mapPanelLoading = false;
  bool layerRides      = false;
  bool layerHeat       = false;
  bool layerDrivers    = false;

  DateTime?   heatLastUpdate;
  Set<Circle> circles     = {};
  Set<Marker> rideMarkers = {};

  List<Map<String, dynamic>> heatPoints         = [];
  List<Map<String, dynamic>> searchingNow       = [];
  List<Map<String, dynamic>> searchingDeliveries = [];
  List<Map<String, dynamic>> onlineDrivers       = [];
  List<Map<String, dynamic>> mapRides            = [];

  // ── Callbacks UI ──────────────────────────────────────────────
  VoidCallback?                        onShowRideRequest;
  VoidCallback?                        onNavigateToRide;
  VoidCallback?                        onRideCancelledExternally;
  void Function(Map<String, dynamic>)? onRideMarkerTap;
  String?                              activeNavigateRideId;

  // ── Stream — notifica sheets abertos via pino ─────────────────
  final _rideClosedController = StreamController<String>.broadcast();
  Stream<String> get rideClosedStream => _rideClosedController.stream;

  // ── Helpers ───────────────────────────────────────────────────
  int get ridesCount    => mapRides.length;
  int get heatCount     => heatPoints.length;
  int get driversCount  => onlineDrivers.length;

  // ── Timers e streams ──────────────────────────────────────────
  Timer?                        _userTimer;
  Timer?                        _fallbackTimer;
  Timer?                        _mapRefreshTimer;
  StreamSubscription<Position>? _positionSub;

  // ─────────────────────────────────────────────────────────────
  // Inicialização
  // ─────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await loadUser();
    await initLocation();
    startUserPolling();
    listenFcm();
    loadUnreadCount();
  }

  // ─────────────────────────────────────────────────────────────
  // FCM
  // ─────────────────────────────────────────────────────────────

  void listenFcm() {
    FirebaseMessaging.onMessage.listen((message) async {
      loadUnreadCount();

      await localNotifications.show(
        100,
        message.notification?.title ?? '📢 Aviso GoRide',
        message.notification?.body  ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'goride_general',
            'Avisos GoRide',
            importance:      Importance.high,
            priority:        Priority.high,
            playSound:       true,
            enableVibration: true,
            icon:            '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
      );

      final type = message.data['type'];

      if (isOnline && !hasNewRide) {
        if (type == 'new_ride') {
          await fetchAndShowRide(rideId: message.data['ride_id']);
        } else if (type == 'new_delivery' && acceptsDelivery) {
          await fetchAndShowDelivery(
              deliveryId: message.data['delivery_id']);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      loadUnreadCount();
      final type = message.data['type'];
      if (type == 'new_ride') {
        fetchAndShowRide(rideId: message.data['ride_id']);
      } else if (type == 'new_delivery' && acceptsDelivery) {
        fetchAndShowDelivery(deliveryId: message.data['delivery_id']);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Notificações — badge
  // ─────────────────────────────────────────────────────────────

  Future<void> loadUnreadCount() async {
    try {
      final res = await ApiClient().dio.get('/notifications');
      unreadNotifications = res.data['unread_count'] ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Polling — dados do usuário 60s
  // ─────────────────────────────────────────────────────────────

  void startUserPolling() {
    _userTimer?.cancel();
    _userTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await loadUser();
      await loadUnreadCount();
    });
  }

  // ─────────────────────────────────────────────────────────────
  // WebSocket
  // ─────────────────────────────────────────────────────────────

  Future<void> startWsRideListener() async {
    ws.off('ride.requested');
    ws.off('ride.cancelled');
    ws.off('ride.accepted');
    ws.off('delivery.requested');

    await ws.connect();
    await ws.subscribeToPublic('rides');

    // Só assina canal de deliveries se o motorista aceita
    if (acceptsDelivery) {
      await ws.subscribeToPublic('deliveries');
    }

    // ── Corridas ──────────────────────────────────────────────
    ws.on('ride.requested', (payload) async {
      if (!isOnline || hasNewRide) return;
      await fetchAndShowRide(
        rideId:          payload['ride_id']?.toString() ??
                         payload['id']?.toString(),
        fallbackPayload: payload,
      );
    });

    ws.on('ride.cancelled', (payload) {
      final id = payload['ride_id']?.toString();
      if (id == null) return;
      _rideClosedController.add(id);
      if (pendingRide?['id']?.toString() == id) {
        onRideCancelledExternally?.call();
      }
    });

    ws.on('ride.accepted', (payload) {
      final id = payload['ride_id']?.toString();
      if (id == null) return;
      _rideClosedController.add(id);
      if (pendingRide?['id']?.toString() == id) {
        onRideCancelledExternally?.call();
      }
    });

    // ── Entregas ──────────────────────────────────────────────
    ws.on('delivery.requested', (payload) async {
      if (!isOnline || hasNewRide || !acceptsDelivery) return;
      await fetchAndShowDelivery(
        deliveryId:      payload['delivery_id']?.toString(),
        fallbackPayload: payload,
      );
    });

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!isOnline || hasNewRide) return;
      // Tenta corrida primeiro, depois entrega
      await fetchAndShowRide();
      if (!hasNewRide && acceptsDelivery) {
        await fetchAndShowDelivery();
      }
    });
  }

  void stopWsRideListener() {
    ws.off('ride.requested');
    ws.off('ride.cancelled');
    ws.off('ride.accepted');
    ws.off('delivery.requested');
    _fallbackTimer?.cancel();
  }

  // ─────────────────────────────────────────────────────────────
  // Corrida — busca e exibe
  // ─────────────────────────────────────────────────────────────

  Future<void> fetchAndShowRide({
    String? rideId,
    Map<String, dynamic>? fallbackPayload,
  }) async {
    if (hasNewRide || fetchingRide) return;
    fetchingRide = true;

    try {
      final rides = await homeService.getPendingRides();
      if (rides.isEmpty || hasNewRide) return;

      Map<String, dynamic> rideData;
      if (rideId != null) {
        rideData = rides.firstWhere(
          (r) => r['id']?.toString() == rideId,
          orElse: () => rides.first,
        );
      } else {
        rideData = rides.first;
      }

      if (hasNewRide) return;
      // Marca tipo para o sheet saber como renderizar
      pendingRide = {...rideData, 'service_type': 'ride'};
      hasNewRide  = true;
      notifyListeners();
      await _notifyNewRide();
      onShowRideRequest?.call();
    } catch (_) {
      if (fallbackPayload != null && !hasNewRide) {
        pendingRide = {
          'id':                  fallbackPayload['ride_id'] ?? '',
          'service_type':        'ride',
          'estimated_price':     fallbackPayload['estimated_price'] ?? 0.0,
          'distance_km':         fallbackPayload['distance_km'],
          'duration_minutes':    fallbackPayload['duration_minutes'],
          'origin_address':      fallbackPayload['origin_address'],
          'destination_address': fallbackPayload['destination_address'],
          'payment_method':      fallbackPayload['payment_method'],
          'fee_type':            'fixed',
          'fee_value':           0.0,
        };
        hasNewRide = true;
        notifyListeners();
        await _notifyNewRide();
        onShowRideRequest?.call();
      }
    } finally {
      fetchingRide = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Entrega — busca e exibe
  // ─────────────────────────────────────────────────────────────

  Future<void> fetchAndShowDelivery({
    String? deliveryId,
    Map<String, dynamic>? fallbackPayload,
  }) async {
    if (hasNewRide || fetchingRide) return;
    fetchingRide = true;

    try {
      final deliveries = await homeService.getPendingDeliveries();
      if (deliveries.isEmpty || hasNewRide) return;

      Map<String, dynamic> deliveryData;
      if (deliveryId != null) {
        deliveryData = deliveries.firstWhere(
          (d) => d['id']?.toString() == deliveryId,
          orElse: () => deliveries.first,
        );
      } else {
        deliveryData = deliveries.first;
      }

      if (hasNewRide) return;
      // Marca tipo para o sheet saber como renderizar
      pendingRide = {...deliveryData, 'service_type': 'delivery'};
      hasNewRide  = true;
      notifyListeners();
      await _notifyNewRide();
      onShowRideRequest?.call();
    } catch (_) {
      if (fallbackPayload != null && !hasNewRide) {
        pendingRide = {
          'id':                  fallbackPayload['delivery_id'] ?? '',
          'service_type':        'delivery',
          'estimated_price':     fallbackPayload['estimated_price'] ?? 0.0,
          'distance_km':         fallbackPayload['distance_km'],
          'duration_minutes':    fallbackPayload['duration_minutes'],
          'origin_address':      fallbackPayload['origin_address'],
          'destination_address': fallbackPayload['destination_address'],
          'payment_method':      fallbackPayload['payment_method'],
          'package_description': fallbackPayload['package_description'],
        };
        hasNewRide = true;
        notifyListeners();
        await _notifyNewRide();
        onShowRideRequest?.call();
      }
    } finally {
      fetchingRide = false;
    }
  }

  void clearRide() {
    hasNewRide  = false;
    pendingRide = null;
    notifyListeners();
  }

  Future<void> _notifyNewRide() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Localização
  // ─────────────────────────────────────────────────────────────

  Future<void> initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high),
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
    currentPosition = position;
    mapController?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(position.latitude, position.longitude), 15,
    ));
    if (isOnline) homeService.updateLocation(position);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // Dados do motorista
  // ─────────────────────────────────────────────────────────────

  Future<void> loadUser() async {
    try {
      final data = await homeService.loadDriverData();
      user          = data['user']          as UserModel;
      driverInfo    = data['driver']        as Map<String, dynamic>?;
      walletInfo    = data['wallet']        as Map<String, dynamic>?;
      needsVehicle  = data['needsVehicle']  as bool;
      needsApproval = data['needsApproval'] as bool;
      isOnline      = data['isOnline']      as bool;

      // Carrega service_types do motorista
      final types = driverInfo?['service_types'];
      if (types is List) {
        serviceTypes = types.cast<String>();
      }

      loading = false;
      notifyListeners();

      if (isOnline) await startWsRideListener();

      final activeRideId = await homeService.checkActiveRide();
      if (activeRideId != null) {
        activeNavigateRideId = activeRideId;
        onNavigateToRide?.call();
      }
    } catch (_) {
      loading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Toggle online / offline
  // ─────────────────────────────────────────────────────────────

  Future<String?> toggleOnline() async {
    if (!isOnline) {
      if (needsVehicle)  return 'Adicione seu veículo antes de ficar online.';
      if (needsApproval) return 'Aguarde a aprovação do seu cadastro.';
    }
    try {
      await homeService.setOnlineStatus(!isOnline);
      isOnline = !isOnline;
      notifyListeners();
      if (isOnline) {
        if (currentPosition != null) {
          await homeService.updateLocation(currentPosition!);
        }
        await startWsRideListener();
      } else {
        stopWsRideListener();
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // Camadas do mapa
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchMapData() async {
    mapPanelLoading = true;
    notifyListeners();
    try {
      final data          = await homeService.getMapData();
      heatPoints          = data['heat_points']!;
      searchingNow        = data['searching_now']!;
      searchingDeliveries = data['searching_deliveries']!;
      onlineDrivers       = data['online_drivers']!;
      heatLastUpdate      = DateTime.now();

      // Mescla corridas + entregas para os markers
      mapRides = [
        ...searchingNow,
        ...searchingDeliveries,
      ];

      if (layerHeat || layerDrivers) buildCircles();
      if (layerRides) _buildRideMarkers();
    } catch (_) {
    } finally {
      mapPanelLoading = false;
      notifyListeners();
    }
  }

  void _startMapRefresh() {
    if (_mapRefreshTimer?.isActive ?? false) return;
    _mapRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!layerRides && !layerHeat && !layerDrivers) {
        _mapRefreshTimer?.cancel();
        return;
      }
      await _fetchMapData();
    });
  }

  void _stopMapRefreshIfIdle() {
    if (!layerRides && !layerHeat && !layerDrivers) {
      _mapRefreshTimer?.cancel();
    }
  }

  Future<void> toggleLayerRides() async {
    layerRides = !layerRides;
    notifyListeners();
    if (layerRides) {
      await _fetchMapData();
      _startMapRefresh();
    } else {
      rideMarkers = {};
      mapRides    = [];
      _stopMapRefreshIfIdle();
      notifyListeners();
    }
  }

  Future<void> toggleLayerHeat() async {
    layerHeat = !layerHeat;
    notifyListeners();
    if (layerHeat) {
      await _fetchMapData();
      _startMapRefresh();
    } else {
      _stopMapRefreshIfIdle();
      buildCircles();
    }
  }

  Future<void> toggleLayerDrivers() async {
    layerDrivers = !layerDrivers;
    notifyListeners();
    if (layerDrivers) {
      await _fetchMapData();
      _startMapRefresh();
    } else {
      _stopMapRefreshIfIdle();
      buildCircles();
    }
  }

  void buildCircles() {
    final result = <Circle>{};
    int i = 0;

    if (layerHeat) {
      for (final p in heatPoints) {
        final weight = (p['weight'] as num?)?.toDouble() ?? 0.5;
        result.add(Circle(
          circleId:  CircleId('heat_$i'),
          center:    LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          ),
          radius:    200,
          fillColor: Color.lerp(
            Colors.orange.withValues(alpha: 0.15),
            Colors.red.withValues(alpha: 0.50),
            weight,
          )!,
          strokeWidth: 0,
        ));
        i++;
      }
    }

    if (layerDrivers) {
      for (final p in onlineDrivers) {
        result.add(Circle(
          circleId:    CircleId('driver_$i'),
          center:      LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          ),
          radius:      80,
          fillColor:   Colors.blue.withValues(alpha: 0.35),
          strokeColor: Colors.blue.withValues(alpha: 0.6),
          strokeWidth: 1,
        ));
        i++;
      }
    }

    circles = result;
    notifyListeners();
  }

  // Markers: verde para corridas, laranja para entregas
  void _buildRideMarkers() {
    final markers = <Marker>{};

    for (final item in mapRides) {
      final lat      = (item['lat'] as num).toDouble();
      final lng      = (item['lng'] as num).toDouble();
      final isDelivery = item['type'] == 'delivery';
      final itemCopy = Map<String, dynamic>.from(item);

      markers.add(Marker(
        markerId: MarkerId('${item['type']}_${item['id']}'),
        position: LatLng(lat, lng),
        icon:     BitmapDescriptor.defaultMarkerWithHue(
          isDelivery
              ? BitmapDescriptor.hueOrange  // laranja para entregas
              : BitmapDescriptor.hueGreen,  // verde para corridas
        ),
        onTap: () => onRideMarkerTap?.call(itemCopy),
      ));
    }

    rideMarkers = markers;
    notifyListeners();
  }

  void removeRideFromLayer(String id) {
    mapRides.removeWhere((r) => r['id'].toString() == id);
    rideMarkers.removeWhere((m) =>
        m.markerId.value == 'ride_$id' ||
        m.markerId.value == 'delivery_$id');
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  String get balanceLabel {
    final b = double.tryParse(
        walletInfo?['balance']?.toString() ?? '0') ?? 0.0;
    return 'R\$ ${b.toStringAsFixed(2)}';
  }

  bool get isBalanceNegative {
    final b = double.tryParse(
        walletInfo?['balance']?.toString() ?? '0') ?? 0.0;
    return b < 0;
  }

  // ─────────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _userTimer?.cancel();
    _fallbackTimer?.cancel();
    _mapRefreshTimer?.cancel();
    _positionSub?.cancel();
    _rideClosedController.close();
    mapController?.dispose();
    ws.off('ride.requested');
    ws.off('ride.cancelled');
    ws.off('ride.accepted');
    ws.off('delivery.requested');
    ws.disconnect();
    super.dispose();
  }
}