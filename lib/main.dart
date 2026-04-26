import 'package:flutter/material.dart';
import 'core/config/api_client.dart';
import 'core/config/app_theme.dart';
import 'core/config/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

// ─────────────────────────────────────────────────────────────────
// Plugin de notificações locais — instância global
// ─────────────────────────────────────────────────────────────────
final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

// ─────────────────────────────────────────────────────────────────
// Handler FCM — app fechado (top-level obrigatório)
// ─────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App fechado: Android já exibe a notificação automaticamente via FCM
  // Não precisa fazer nada aqui por enquanto
}

// ─────────────────────────────────────────────────────────────────
// main
// ─────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 2. Notificações locais (para exibir quando app está em foreground)
  await localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS:     DarwinInitializationSettings(),
    ),
  );

  // 3. Permissão FCM (Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    sound: true,
    badge: true,
  );

  // 4. ApiClient
  ApiClient().init();

  runApp(const GoRideDriverApp());
}

// ─────────────────────────────────────────────────────────────────
// App
// ─────────────────────────────────────────────────────────────────
class GoRideDriverApp extends StatelessWidget {
  const GoRideDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title:                      'GoRide Motorista',
      debugShowCheckedModeBanner: false,
      theme:                      AppTheme.theme,
      routerConfig:               AppRouter.router,
    );
  }
}