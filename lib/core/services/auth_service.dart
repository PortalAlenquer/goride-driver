import '../config/api_client.dart';
import '../config/api_constants.dart';
import '../models/user_model.dart';
import 'chat_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _api = ApiClient();

  // ── Login ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.dio.post(ApiConstants.login, data: {
      'email':    email,
      'password': password,
    });

    await _api.saveToken(response.data['token']);

    // Salva token FCM após login — agora há autenticação disponível
    // Best-effort: falha silenciosa para não bloquear o login
    ChatService().saveFcmToken();

    return response.data;
  }

  // ── Dados do usuário atual ────────────────────────────────────

  Future<UserModel> getMe() async {
    final response = await _api.dio.get(ApiConstants.me);
    return UserModel.fromJson(response.data['user']);
  }

  // ── Logout ────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _api.dio.post(ApiConstants.logout);
    } catch (_) {}
    await _api.deleteToken();
  }

  // ── Verificar autenticação ────────────────────────────────────

  Future<bool> isLoggedIn() async {
    final token = await _api.getToken();
    return token != null;
  }
}