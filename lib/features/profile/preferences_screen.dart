import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_theme.dart';
import '../../core/config/api_client.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _api = ApiClient();

  bool _loading = true;
  bool _saving  = false;

  // Formas de pagamento
  bool _cash   = true;
  bool _pix    = true;
  bool _card   = false;
  bool _wallet = false;

  // Tipos de serviço
  bool _ride     = true;
  bool _delivery = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.dio.get('/driver/me');
      final driver = res.data['driver'] as Map<String, dynamic>;

      final payments = List<String>.from(driver['payment_methods'] ?? ['cash', 'pix']);
      final services = List<String>.from(driver['service_types']   ?? ['ride']);

      setState(() {
        _cash    = payments.contains('cash');
        _pix     = payments.contains('pix');
        _card    = payments.contains('card');
        _wallet  = payments.contains('wallet');
        _ride     = services.contains('ride');
        _delivery = services.contains('delivery');
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    // Validação — pelo menos uma forma de pagamento
    final payments = [
      if (_cash)   'cash',
      if (_pix)    'pix',
      if (_card)   'card',
      if (_wallet) 'wallet',
    ];
    if (payments.isEmpty) {
      _showSnack('Selecione ao menos uma forma de pagamento.', AppTheme.warning);
      return;
    }

    // Validação — pelo menos um tipo de serviço
    final services = [
      if (_ride)     'ride',
      if (_delivery) 'delivery',
    ];
    if (services.isEmpty) {
      _showSnack('Selecione ao menos um tipo de serviço.', AppTheme.warning);
      return;
    }

    setState(() => _saving = true);
    try {
      await _api.dio.put('/driver/payment-methods', data: {
        'payment_methods': payments,
        'service_types':   services,
      });
      if (mounted) _showSnack('Preferências salvas!', AppTheme.secondary);
    } catch (_) {
      if (mounted) _showSnack('Erro ao salvar.', AppTheme.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Personalização'),
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Formas de pagamento ───────────────────────
                _SectionHeader(
                  icon:  Icons.payment,
                  title: 'Formas de pagamento aceitas',
                  subtitle: 'Selecione como deseja receber pelos seus serviços',
                ),
                const SizedBox(height: 16),

                _ToggleCard(
                  icon:    Icons.attach_money,
                  color:   Colors.green.shade600,
                  title:   'Dinheiro',
                  subtitle: 'Pagamento em espécie',
                  value:   _cash,
                  onChanged: (v) => setState(() => _cash = v),
                ),
                _ToggleCard(
                  icon:    Icons.pix,
                  color:   Colors.teal,
                  title:   'PIX',
                  subtitle: 'Transferência instantânea',
                  value:   _pix,
                  onChanged: (v) => setState(() => _pix = v),
                ),
                _ToggleCard(
                  icon:    Icons.credit_card,
                  color:   AppTheme.primary,
                  title:   'Cartão',
                  subtitle: 'Crédito ou débito via maquininha',
                  value:   _card,
                  onChanged: (v) => setState(() => _card = v),
                ),
                _ToggleCard(
                  icon:    Icons.account_balance_wallet,
                  color:   AppTheme.secondary,
                  title:   'Carteira',
                  subtitle: 'Saldo na plataforma',
                  value:   _wallet,
                  onChanged: (v) => setState(() => _wallet = v),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),

                // ── Tipo de serviço ───────────────────────────
                _SectionHeader(
                  icon:  Icons.tune,
                  title: 'Tipo de serviço',
                  subtitle: 'Escolha quais solicitações deseja receber',
                ),
                const SizedBox(height: 16),

                _ToggleCard(
                  icon:    Icons.directions_car,
                  color:   AppTheme.primary,
                  title:   'Transporte',
                  subtitle: 'Corridas de passageiros',
                  value:   _ride,
                  onChanged: (v) => setState(() => _ride = v),
                ),
                _ToggleCard(
                  icon:    Icons.delivery_dining,
                  color:   Colors.orange,
                  title:   'Delivery',
                  subtitle: 'Entregas',
                  value:   _delivery,
                  onChanged: (v) => setState(() => _delivery = v),

                ),

                const SizedBox(height: 40),

                // ── Botão salvar ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Salvar preferências'),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Widgets locais
// ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                  color:      AppTheme.dark,
                )),
              const SizedBox(height: 2),
              Text(subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color:    AppTheme.gray,
                )),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;
  final bool     value;
  final bool     enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color:        value
              ? color.withValues(alpha: 0.06)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? color.withValues(alpha: 0.3)
                : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize:   15,
              color:      AppTheme.dark,
            )),
          subtitle: Text(subtitle,
            style: const TextStyle(
              fontSize: 12,
              color:    AppTheme.gray,
            )),
          value:           value,
          onChanged:       enabled ? onChanged : null,
          activeColor:     color,
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return color.withValues(alpha: 0.3);
            }
            return Colors.grey.shade300;
          }),
        ),
      ),
    );
  }
}