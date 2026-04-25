import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_theme.dart';
import '../../core/config/api_client.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final List<Map<String, dynamic>> _methods = [
    {'value': 'cash',   'label': 'Dinheiro',  'icon': Icons.attach_money,           'selected': true},
    {'value': 'pix',    'label': 'PIX',        'icon': Icons.pix,                    'selected': true},
    {'value': 'card',   'label': 'Cartão',     'icon': Icons.credit_card,            'selected': false},
    {'value': 'wallet', 'label': 'Carteira',   'icon': Icons.account_balance_wallet, 'selected': false},
  ];
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentMethods();
  }

  Future<void> _loadCurrentMethods() async {
    try {
      final response = await ApiClient().dio.get('/driver/me');
      final methods  = List<String>.from(
        response.data['driver']?['payment_methods'] ?? ['cash', 'pix']);
      setState(() {
        for (var m in _methods) {
          m['selected'] = methods.contains(m['value']);
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final selected = _methods
      .where((m) => m['selected'] == true)
      .map((m) => m['value'] as String)
      .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos uma forma de pagamento.'),
          backgroundColor: AppTheme.danger,
        ));
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiClient().dio.put('/driver/payment-methods', data: {
        'payment_methods': selected,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formas de pagamento atualizadas!'),
            backgroundColor: AppTheme.secondary,
          ));
        context.push('/profile');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar.'),
            backgroundColor: AppTheme.danger,
          ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Formas de pagamento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.push('/profile'),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payment, size: 48, color: AppTheme.secondary),
                const SizedBox(height: 16),
                const Text('Formas de pagamento aceitas',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Você só receberá corridas com as formas de pagamento selecionadas.',
                  style: TextStyle(color: AppTheme.gray)),
                const SizedBox(height: 32),

                ..._methods.map((method) => GestureDetector(
                  onTap: () => setState(
                    () => method['selected'] = !method['selected']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: method['selected'] == true
                        ? AppTheme.secondary.withValues(alpha: 0.05)
                        : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: method['selected'] == true
                          ? AppTheme.secondary
                          : const Color(0xFFE5E7EB),
                        width: method['selected'] == true ? 2 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: method['selected'] == true
                            ? AppTheme.secondary.withValues(alpha: 0.1)
                            : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          method['icon'] as IconData,
                          color: method['selected'] == true
                            ? AppTheme.secondary : AppTheme.gray,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(method['label'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: method['selected'] == true
                              ? AppTheme.secondary : AppTheme.dark,
                          )),
                      ),
                      if (method['selected'] == true)
                        const Icon(Icons.check_circle,
                          color: AppTheme.secondary),
                    ]),
                  ),
                )),

                const Spacer(),

                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary),
                  child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Salvar'),
                ),
              ],
            ),
          ),
    );
  }
}