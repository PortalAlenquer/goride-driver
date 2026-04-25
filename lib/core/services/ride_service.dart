import '../config/api_client.dart';
import '../models/ride_model.dart';

class RideService {
  static final RideService _instance = RideService._internal();
  factory RideService() => _instance;
  RideService._internal();

  final _api = ApiClient();

  // ── Carregar corrida ──────────────────────────────────────────

  Future<RideModel> getRide(String rideId) async {
    final res = await _api.dio.get('/rides/$rideId');
    return RideModel.fromJson(res.data['ride']);
  }

  // ── Atualizar status ──────────────────────────────────────────

  Future<void> updateStatus(String rideId, String status) async {
    await _api.dio.put('/rides/$rideId/status', data: {'status': status});
  }

  // ── Rejeitar corrida ──────────────────────────────────────────

  Future<void> rejectRide(String rideId) async {
    await _api.dio.post('/rides/$rideId/reject');
  }

  // ── Aceitar corrida ───────────────────────────────────────────

  Future<void> acceptRide(String rideId) async {
    await _api.dio.post('/rides/$rideId/accept');
  }

  // ── Corridas pendentes ────────────────────────────────────────

  Future<List<RideModel>> getPendingRides() async {
    final res   = await _api.dio.get('/driver/rides/pending');
    final rides = res.data['rides'] as List? ?? [];
    return rides.map((r) => RideModel.fromJson(r)).toList();
  }

  // ── Histórico paginado ────────────────────────────────────────
  // API retorna estrutura padrão do Laravel paginate():
  // { current_page, last_page, data: [...] }

  Future<RideHistoryPage> getRideHistory({int page = 1}) async {
    final res = await _api.dio.get('/rides',
      queryParameters: {'page': page});

    final rides = (res.data['data'] as List? ?? [])
        .map((r) => RideModel.fromJson(r))
        .toList();

    final currentPage = res.data['current_page'] as int? ?? 1;
    final lastPage    = res.data['last_page']    as int? ?? 1;

    return RideHistoryPage(
      rides:       rides,
      currentPage: currentPage,
      lastPage:    lastPage,
      hasMore:     currentPage < lastPage,
    );
  }
}

// ── Modelo de página ──────────────────────────────────────────────

class RideHistoryPage {
  final List<RideModel> rides;
  final int currentPage;
  final int lastPage;
  final bool hasMore;

  const RideHistoryPage({
    required this.rides,
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
  });
}