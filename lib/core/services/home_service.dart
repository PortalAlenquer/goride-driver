import 'package:geolocator/geolocator.dart';
import '../config/api_client.dart';
import '../models/user_model.dart';

class HomeService {
  static final HomeService _instance = HomeService._internal();
  factory HomeService() => _instance;
  HomeService._internal();

  final _api = ApiClient();

  // ── Dados do motorista ────────────────────────────────────────

  Future<Map<String, dynamic>> loadDriverData() async {
    final userRes   = await _api.dio.get('/auth/me');
    final driverRes = await _api.dio.get('/driver/me');
    final walletRes = await _api.dio.get('/wallet/balance');

    final user       = UserModel.fromJson(userRes.data['user']);
    final driverData = driverRes.data['driver'] as Map<String, dynamic>?;

    // /wallet/balance retorna { balance, negative_limit } no root
    final walletData = walletRes.data as Map<String, dynamic>?;

    final hasVehicle  = (driverData?['vehicles'] as List?)?.isNotEmpty == true;
    final hasApproval = driverData?['approved_at'] != null;

    return {
      'user':          user,
      'driver':        driverData,
      'wallet':        walletData,
      'needsVehicle':  !hasVehicle,
      'needsApproval': !hasApproval,
      'isOnline':      driverData?['is_online'] == true,
    };
  }

  // ── Corrida ativa — para back-to-back ─────────────────────────
  // Retorna o ID da corrida ativa se existir, null caso contrário

  Future<String?> checkActiveRide() async {
    try {
      final res  = await _api.dio.get('/driver/active-ride');
      final ride = res.data['ride'] as Map<String, dynamic>?;
      return ride?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  // ── Status online/offline ─────────────────────────────────────

  Future<void> setOnlineStatus(bool isOnline) async {
    await _api.dio.put('/driver/status', data: {'is_online': isOnline});
  }

  // ── Localização ───────────────────────────────────────────────

  Future<void> updateLocation(Position position) async {
    await _api.dio.post('/rides/driver/location', data: {
      'lat': position.latitude,
      'lng': position.longitude,
    });
  }

  // ── Corridas pendentes ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingRides() async {
    final res   = await _api.dio.get('/driver/rides/pending');
    final rides = res.data['rides'] as List?;
    return rides?.cast<Map<String, dynamic>>() ?? [];
  }

  // ── Aceitar / rejeitar corrida ────────────────────────────────

  Future<void> acceptRide(String rideId) async {
    await _api.dio.post('/rides/$rideId/accept');
  }

  Future<void> rejectRide(String rideId) async {
    await _api.dio.post('/rides/$rideId/reject');
  }

  // ── Dados do mapa ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getMapData() async {
    final res = await _api.dio.get('/driver/map-data');
    return {
      'heat_points':    List<Map<String, dynamic>>.from(res.data['heat_points']    ?? []),
      'searching_now':  List<Map<String, dynamic>>.from(res.data['searching_now']  ?? []),
      'online_drivers': List<Map<String, dynamic>>.from(res.data['online_drivers'] ?? []),
    };
  }
}