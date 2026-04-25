import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/api_client.dart';
import '../../core/config/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Captura o router antes de qualquer await — resolve BuildContext async gap
    final router = GoRouter.of(context);

    try {
      final token = await ApiClient().getToken();

      // Sem token local → vai direto pro login
      if (token == null) {
        router.go('/login');
        return;
      }

      // Token existe — valida com a API chamando /auth/me
      // Se o token estiver expirado ou inválido, a API retorna 401
      // e o interceptor do Dio lança DioException, caindo no catch abaixo
      final response = await ApiClient().dio.get('/auth/me');
      final role     = response.data['user']?['role'];

      // Garante que é um motorista — não um passageiro com token válido
      if (role == 'driver') {
        router.go('/home');
      } else {
        // Token válido mas não é motorista — limpa e manda pro login
        await ApiClient().deleteToken();
        router.go('/login');
      }
    } catch (_) {
      // Token expirado, sem internet, ou qualquer erro de API
      // Limpa o token inválido para não entrar em loop
      await ApiClient().deleteToken();
      router.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.secondary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.drive_eta,
                size: 60, color: AppTheme.secondary),
            ),
            const SizedBox(height: 24),
            const Text('GoRide',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              )),
            const SizedBox(height: 8),
            const Text('Painel do motorista',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}