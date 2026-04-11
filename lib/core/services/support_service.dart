import '../api/api_client.dart';

class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  final _api = ApiClient();

  Future<Map<String, dynamic>> loadByLocation({
    required double lat,
    required double lng,
  }) async {
    final res = await _api.dio.get('/driver/fee-by-location', queryParameters: {
      'lat': lat,
      'lng': lng,
    });
    return res.data as Map<String, dynamic>;
  }
}