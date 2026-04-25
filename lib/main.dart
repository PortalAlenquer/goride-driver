import 'package:flutter/material.dart';
import 'core/config/api_client.dart';
import 'core/config/app_theme.dart';
import 'core/config/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Handler para mensagens FCM em background (deve ser top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configura handler de background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inicializa ApiClient
  ApiClient().init();

  // NOTA: saveFcmToken() NÃO é chamado aqui
  // É chamado no auth_service.dart após login bem sucedido
  // pois precisa do token de autenticação para enviar ao backend

  runApp(const GoRideDriverApp());
}

class GoRideDriverApp extends StatelessWidget {
  const GoRideDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GoRide Motorista',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: AppRouter.router,
    );
  }
}