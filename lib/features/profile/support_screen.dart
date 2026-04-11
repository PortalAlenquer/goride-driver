import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/support_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _service = SupportService();

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // baixa precisão — só para cidade
        ),
      );
      final data = await _service.loadByLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
      setState(() { _data = data; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Não foi possível obter sua localização.'; _loading = false; });
    }
  }

  // ── Ações de contato ──────────────────────────────────────────

  Future<void> _openWhatsApp(String number) async {
    final appName = _data?['app_name'] ?? 'GoRide';
    final message = Uri.encodeComponent('Olá! Preciso de suporte no $appName.');
    final url = Uri.parse('https://wa.me/$number?text=$message');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _openPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _openEmail(String email) async {
    final appName = _data?['app_name'] ?? 'GoRide';
    final url = Uri.parse('mailto:$email?subject=Suporte $appName');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _feeLabel() {
    if (_data == null) return '—';
    final type  = _data!['fee_type'] ?? 'fixed';
    final value = double.tryParse(_data!['fee_value']?.toString() ?? '0') ?? 0.0;
    if (type == 'percentage') return '${value.toStringAsFixed(0)}% por corrida';
    return 'R\$ ${value.toStringAsFixed(2)} por corrida';
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Suporte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Localização e tarifa ──────────────────────
                  _SectionCard(
                    icon:  Icons.location_on,
                    color: AppTheme.secondary,
                    title: _data?['franchise'] != null
                      ? 'Você está em ${_data!['franchise']}'
                      : 'Região sem franquia cadastrada',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Text('Tarifa aplicada:',
                          style: TextStyle(
                            color: AppTheme.gray, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.monetization_on,
                            color: AppTheme.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text(_feeLabel(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary)),
                        ]),
                        const SizedBox(height: 8),
                        const Text(
                          'A tarifa é descontada do seu saldo a cada corrida concluída.',
                          style: TextStyle(
                            fontSize: 12, color: AppTheme.gray)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Contato do franqueado ─────────────────────
                  if (_data?['franchise_contact'] != null) ...[
                    _SectionCard(
                      icon:  Icons.store,
                      color: AppTheme.primary,
                      title: 'Responsável pela região',
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _ContactRow(
                            icon:  Icons.person_outline,
                            label: _data!['franchise_contact']['name'] ?? '—',
                          ),
                          if (_data!['franchise_contact']['phone'] != null)
                            _ContactRow(
                              icon:    Icons.phone_outlined,
                              label:   _data!['franchise_contact']['phone'],
                              onTap:   () => _openPhone(
                                _data!['franchise_contact']['phone']),
                            ),
                          if (_data!['franchise_contact']['email'] != null)
                            _ContactRow(
                              icon:    Icons.email_outlined,
                              label:   _data!['franchise_contact']['email'],
                              onTap:   () => _openEmail(
                                _data!['franchise_contact']['email']),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Suporte da plataforma ─────────────────────
                  _SectionCard(
                    icon:  Icons.headset_mic,
                    color: AppTheme.warning,
                    title: 'Suporte ${_data?['app_name'] ?? 'GoRide'}',
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        if (_data?['support_whatsapp'] != null)
                          _ContactButton(
                            icon:    Icons.chat,
                            label:   'WhatsApp',
                            color:   const Color(0xFF25D366),
                            onTap:   () => _openWhatsApp(
                              _data!['support_whatsapp']),
                          ),

                        if (_data?['support_phone'] != null) ...[
                          const SizedBox(height: 8),
                          _ContactButton(
                            icon:    Icons.phone,
                            label:   _data!['support_phone'],
                            color:   AppTheme.primary,
                            onTap:   () => _openPhone(
                              _data!['support_phone']),
                          ),
                        ],

                        if (_data?['support_email'] != null) ...[
                          const SizedBox(height: 8),
                          _ContactButton(
                            icon:    Icons.email,
                            label:   _data!['support_email'],
                            color:   AppTheme.gray,
                            onTap:   () => _openEmail(
                              _data!['support_email']),
                          ),
                        ],
                      ],
                    ),
                  ),

                ],
              ),
            ),
    );
  }
}

// ── Widgets locais ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15))),
          ]),
          child,
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: AppTheme.gray),
          const SizedBox(width: 8),
          Text(label,
            style: TextStyle(
              color: onTap != null ? AppTheme.primary : AppTheme.dark,
              decoration: onTap != null
                ? TextDecoration.underline : null)),
        ]),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off,
              size: 64, color: AppTheme.gray),
            const SizedBox(height: 16),
            Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.gray)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}