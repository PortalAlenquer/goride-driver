// lib/features/onboarding/location_permission_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionScreen extends StatelessWidget {
  final VoidCallback onGranted;
  const LocationPermissionScreen({super.key, required this.onGranted});

  Future<void> _requestPermissions(BuildContext context) async {
    // 1. Permissão em uso
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) return;

    // 2. Permissão em background (Android mostra tela do sistema)
    final bgStatus = await Permission.locationAlways.request();
    if (!bgStatus.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Permita "sempre" nas configurações para receber corridas em background.'
          )),
        );
      }
      return;
    }

    // 3. Permissão de notificações (Android 13+)
    await Permission.notification.request();

    onGranted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 80, color: Color(0xFF6C63FF)),
            const SizedBox(height: 24),
            const Text('Localização em segundo plano',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text(
              'Para receber corridas com o app minimizado, o GoRide precisa '
              'acessar sua localização sempre. Seus dados são usados '
              'somente durante o trabalho.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _requestPermissions(context),
                child: const Text('Permitir localização'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}