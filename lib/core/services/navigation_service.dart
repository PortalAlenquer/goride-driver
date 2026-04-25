import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NavigationService — abre o app de navegação externo com as coordenadas
//
// Fluxo:
//   1. Motorista toca no botão de navegação
//   2. Se já tem preferência salva → abre direto
//   3. Se não tem → exibe sheet para escolher o app
//   4. Salva a preferência para as próximas vezes
//
// Apps suportados:
//   • Waze        — waze://ul?ll={lat},{lng}&navigate=yes
//   • Google Maps — google.navigation:q={lat},{lng}
//   • HERE Maps   — here-route://mylocation/{lat},{lng}/drive
//   • Apple Maps  — maps://?daddr={lat},{lng}       (iOS)
// ─────────────────────────────────────────────────────────────────────────────

enum NavApp { waze, googleMaps, hereMaps, appleMaps }

class NavigationService {
  static const _prefKey = 'preferred_nav_app';

  // ── Retorna a preferência salva (null = não definida) ─────────

  static Future<NavApp?> getPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    return switch (saved) {
      'waze'       => NavApp.waze,
      'googleMaps' => NavApp.googleMaps,
      'hereMaps'   => NavApp.hereMaps,
      'appleMaps'  => NavApp.appleMaps,
      _            => null,
    };
  }

  // ── Salva preferência ─────────────────────────────────────────

  static Future<void> savePreference(NavApp app) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, switch (app) {
      NavApp.waze       => 'waze',
      NavApp.googleMaps => 'googleMaps',
      NavApp.hereMaps   => 'hereMaps',
      NavApp.appleMaps  => 'appleMaps',
    });
  }

  static Future<void> clearPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  // ── Abre o app de navegação ───────────────────────────────────

  static Future<void> navigate({
    required double lat,
    required double lng,
    required NavApp app,
    String? label,
  }) async {
    final uri = _buildUri(app: app, lat: lat, lng: lng, label: label);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // App não instalado — tenta Google Maps como fallback
      if (app != NavApp.googleMaps) {
        final fallback = _buildUri(
          app:   NavApp.googleMaps,
          lat:   lat,
          lng:   lng,
          label: label,
        );
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  static Uri _buildUri({
    required NavApp app,
    required double lat,
    required double lng,
    String? label,
  }) =>
    switch (app) {
      NavApp.waze =>
        Uri.parse('waze://ul?ll=$lat,$lng&navigate=yes'),
      NavApp.googleMaps =>
        Uri.parse('google.navigation:q=$lat,$lng'),
      NavApp.hereMaps =>
        Uri.parse('here-route://mylocation/$lat,$lng/drive'),
      NavApp.appleMaps =>
        Uri.parse('maps://?daddr=$lat,$lng'),
    };

  // ── Sheet de seleção de app ───────────────────────────────────
  // Exibe opções e salva a preferência automaticamente

  static Future<NavApp?> showPickerSheet(BuildContext context) async {
    return showModalBottomSheet<NavApp>(
      context:          context,
      backgroundColor:  Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NavAppPickerSheet(),
    );
  }

  // ── Entry point principal ─────────────────────────────────────
  // Chame este método no botão de navegação do ride_detail_screen

  static Future<void> openNavigation({
    required BuildContext context,
    required double lat,
    required double lng,
    String? label,
  }) async {
    // Verifica preferência salva
    final pref = await getPreference();

    NavApp? chosen = pref;

    // Se não tem preferência, exibe o picker
    if (chosen == null && context.mounted) {
      chosen = await showPickerSheet(context);
      if (chosen == null) return; // usuário fechou sem escolher
      await savePreference(chosen); // salva para próximas vezes
    }

    await navigate(lat: lat, lng: lng, app: chosen!, label: label);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet de seleção do app de navegação
// ─────────────────────────────────────────────────────────────────────────────

class _NavAppPickerSheet extends StatelessWidget {
  static const _apps = [
    (NavApp.waze,       'Waze',         'assets/icons/waze.png',       Colors.blue),
    (NavApp.googleMaps, 'Google Maps',  'assets/icons/gmaps.png',      Colors.red),
    (NavApp.hereMaps,   'HERE Maps',    'assets/icons/here.png',       Colors.cyan),
    (NavApp.appleMaps,  'Apple Maps',   'assets/icons/apple_maps.png', Colors.grey),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Abrir com',
            style: TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Sua escolha será lembrada para as próximas corridas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
          const SizedBox(height: 20),

          ..._apps.map((app) => _AppTile(
            app:   app.$1,
            label: app.$2,
            onTap: () => Navigator.pop(context, app.$1),
          )),

          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
              style: TextStyle(color: Color(0xFF888888)))),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final NavApp       app;
  final String       label;
  final VoidCallback onTap;

  const _AppTile({
    required this.app,
    required this.label,
    required this.onTap,
  });

  IconData get _icon => switch (app) {
    NavApp.waze       => Icons.navigation,
    NavApp.googleMaps => Icons.map,
    NavApp.hereMaps   => Icons.explore,
    NavApp.appleMaps  => Icons.apple,
  };

  Color get _color => switch (app) {
    NavApp.waze       => const Color(0xFF33CCFF),
    NavApp.googleMaps => const Color(0xFF4285F4),
    NavApp.hereMaps   => const Color(0xFF00AFAA),
    NavApp.appleMaps  => const Color(0xFF888888),
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon, color: _color, size: 22)),
          const SizedBox(width: 14),
          Text(label,
            style: const TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios,
            size: 14, color: Color(0xFFAAAAAA)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NavPreferenceScreen — tela de preferências (acessível pelo perfil)
// Permite ao motorista trocar o app de navegação padrão
// ─────────────────────────────────────────────────────────────────────────────

class NavPreferenceScreen extends StatefulWidget {
  const NavPreferenceScreen({super.key});

  @override
  State<NavPreferenceScreen> createState() => _NavPreferenceScreenState();
}

class _NavPreferenceScreenState extends State<NavPreferenceScreen> {
  NavApp? _current;
  bool    _loading = true;

  @override
  void initState() {
    super.initState();
    NavigationService.getPreference().then((p) {
      if (mounted) setState(() { _current = p; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App de navegação')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Escolha qual aplicativo de navegação será aberto '
                'automaticamente durante as corridas.',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
              const SizedBox(height: 20),

              ...[
                (NavApp.waze,       'Waze'),
                (NavApp.googleMaps, 'Google Maps'),
                (NavApp.hereMaps,   'HERE Maps'),
                (NavApp.appleMaps,  'Apple Maps'),
              ].map((app) {
                final selected = _current == app.$1;
                return GestureDetector(
                  onTap: () async {
                    await NavigationService.savePreference(app.$1);
                    if (mounted) setState(() => _current = app.$1);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                        ? const Color(0xFF6366F1).withValues(alpha: 0.06)
                        : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                          ? const Color(0xFF6366F1)
                          : Colors.grey.shade200,
                        width: selected ? 2 : 1)),
                    child: Row(children: [
                      Text(app.$2,
                        style: TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w600,
                          color:      selected
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF222222))),
                      const Spacer(),
                      if (selected)
                        const Icon(Icons.check_circle,
                          color: Color(0xFF6366F1), size: 20)
                      else
                        const Icon(Icons.radio_button_unchecked,
                          color: Color(0xFFAAAAAA), size: 20),
                    ]),
                  ),
                );
              }),

              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await NavigationService.clearPreference();
                  if (mounted) setState(() => _current = null);
                },
                child: const Text('Perguntar sempre',
                  style: TextStyle(color: Color(0xFF888888)))),
            ],
          ),
    );
  }
}