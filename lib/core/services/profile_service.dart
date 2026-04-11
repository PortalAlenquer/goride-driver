import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final _api = ApiClient();

  // ── Helpers ───────────────────────────────────────────────────

  String storageUrl(String path) {
    final base = _api.dio.options.baseUrl.replaceAll('/api', '');
    return '$base/storage/$path';
  }

  // ── Carregar dados ────────────────────────────────────────────

  Future<Map<String, dynamic>> loadProfile() async {
    final userRes   = await _api.dio.get('/auth/me');
    final driverRes = await _api.dio.get('/driver/me');

    final user   = UserModel.fromJson(userRes.data['user']);
    final driver = driverRes.data['driver'] as Map<String, dynamic>?;

    return {'user': user, 'driver': driver};
  }

  // ── Salvar dados pessoais ─────────────────────────────────────

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String cpf,
  }) async {
    await _api.dio.put('/profile', data: {
      'name':  name,
      'phone': phone,
      'cpf':   cpf,
    });
  }

  // ── Upload de avatar ──────────────────────────────────────────

  /// Retorna a nova URL do avatar após upload.
  Future<String?> uploadAvatar(String filePath) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        filePath,
        filename: 'avatar.jpg',
      ),
    });
    final res = await _api.dio.post('/profile/avatar', data: formData);
    final newAvatar = res.data['user']?['avatar'] as String?;
    if (newAvatar == null) return null;
    return storageUrl(newAvatar);
  }
}