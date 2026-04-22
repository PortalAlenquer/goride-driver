import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';

class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  final _api = ApiClient();

  // Cache em memória — evita nova requisição se já carregou na sessão
  Map<String, dynamic>? _cached;
  Map<String, dynamic>? get cached => _cached;
  void clearCache() => _cached = null;

  // ── Carrega dados de suporte ──────────────────────────────────
  //
  // Mesmo padrão do PassengerSupportService:
  //   POST /cities/find-by-location → nome da franquia + contato
  //   GET  /support/settings        → whatsapp/phone/email da plataforma
  //
  // Extra do motorista:
  //   GET  /driver/me               → fee_type e fee_value do plano atual

  Future<Map<String, dynamic>> loadByLocation({
    required double lat,
    required double lng,
  }) async {
    // Três chamadas em paralelo
    final results = await Future.wait([
      _api.dio.post('/cities/find-by-location', data: {'lat': lat, 'lng': lng}),
      _api.dio.get('/support/settings'),
      _api.dio.get('/driver/me'),
    ]);

    final city     = results[0].data['city']   as Map<String, dynamic>?;
    final settings = results[1].data           as Map<String, dynamic>? ?? {};
    final driver   = results[2].data['driver'] as Map<String, dynamic>?;

    // Taxa do plano do motorista
    final plan     = driver?['current_plan']?['plan'] as Map<String, dynamic>?;
    final feeType  = plan?['ride_fee_type']?.toString() ?? 'fixed';
    final feeValue = double.tryParse(
        plan?['ride_fee']?.toString() ?? '0') ?? 0.0;

    _cached = {
      'franchise':         city?['name'],
      'franchise_contact': city != null ? {
        'name':     city['owner']?['name'],
        'phone':    city['phone'],
        'whatsapp': city['whatsapp'],
        'email':    city['email'],
      } : null,
      'fee_type':         feeType,
      'fee_value':        feeValue,
      'app_name':         settings['app_name']        ?? 'GoRide',
      'support_whatsapp': settings['support_whatsapp'],
      'support_phone':    settings['support_phone'],
      'support_email':    settings['support_email'],
    };

    return _cached!;
  }

  // ── Posição: lastKnown (instantâneo) com fallback ─────────────

  Future<Position?> getPosition() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;

      // Última posição conhecida — retorna imediatamente
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;

      // Fallback com timeout
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }
}