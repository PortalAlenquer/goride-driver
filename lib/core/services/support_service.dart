import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';

class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  final _api = ApiClient();

  Map<String, dynamic>? _cached;
  DateTime?             _cachedAt;
  static const _ttl = Duration(minutes: 5);

  Map<String, dynamic>? get cached => _cached;
  void clearCache() { _cached = null; _cachedAt = null; }

  bool get _isCacheValid =>
      _cached != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _ttl;

  // Busca taxa da plataforma pela coordenada GPS — não depende
  // do franchise_id cadastrado no perfil do motorista

  Future<Map<String, dynamic>> loadByLocation({
    required double lat,
    required double lng,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid) return _cached!;

    final res = await _api.dio.get(
      '/driver/fee-by-location',
      queryParameters: {'lat': lat, 'lng': lng},
    );

    final data = res.data as Map<String, dynamic>;

    _cached = {
      'franchise':         data['franchise'],
      'franchise_contact': data['franchise_contact'],
      'fee_type':          data['fee_type']  ?? 'fixed',
      'fee_value':         double.tryParse(
          data['fee_value']?.toString() ?? '0') ?? 0.0,
      'app_name':          data['app_name']         ?? 'GoRide',
      'support_whatsapp':  data['support_whatsapp'],
      'support_phone':     data['support_phone'],
      'support_email':     data['support_email'],
    };

    _cachedAt = DateTime.now();
    return _cached!;
  }

  Future<Position?> getPosition() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }
}