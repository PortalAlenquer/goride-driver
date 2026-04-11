import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/services/chat_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl= TextEditingController();
  final _phoneCtrl= TextEditingController();
  final _cpfCtrl  = TextEditingController();
  final _passCtrl = TextEditingController();

  int  _step   = 0;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cpfCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Registro ──────────────────────────────────────────────────

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final authResponse = await ApiClient().dio.post('/auth/register', data: {
        'name':                  _nameCtrl.text.trim(),
        'email':                 _emailCtrl.text.trim(),
        'phone':                 _phoneCtrl.text.trim(),
        'cpf':                   _cpfCtrl.text.trim(),
        'password':              _passCtrl.text,
        'password_confirmation': _passCtrl.text,
        'role':                  'driver',
      });

      await ApiClient().saveToken(authResponse.data['token']);

      // Salva token FCM após registro
      ChatService().saveFcmToken();

      if (mounted) context.go('/home');
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data['message'] ?? 'Erro ao cadastrar.'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Navegação entre steps ─────────────────────────────────────

  void _nextStep() {
    if (_step == 0) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _step = 1);
    } else {
      _register();
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cadastro de motorista'),
        leading: _step > 0
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _step--),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/login'),
            ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [

            // Progress
            LinearProgressIndicator(
              value: (_step + 1) / 2,
              backgroundColor: Colors.grey.shade200,
              color: AppTheme.secondary,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Passo ${_step + 1} de 2',
                    style: const TextStyle(
                      color: AppTheme.gray, fontSize: 12)),
                  Text(
                    ['Dados pessoais', 'Sobre as tarifas'][_step],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _step == 0
                  ? _buildStep0()
                  : _buildStep1(),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _loading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary),
                child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_step == 0
                    ? 'Próximo'
                    : 'Finalizar cadastro'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0 — Dados pessoais ───────────────────────────────────

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.person_outline,
          size: 48, color: AppTheme.secondary),
        const SizedBox(height: 16),
        const Text('Dados pessoais',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nome completo',
            prefixIcon: Icon(Icons.person_outlined)),
          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            prefixIcon: Icon(Icons.email_outlined)),
          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefone (WhatsApp)',
            prefixIcon: Icon(Icons.phone_outlined)),
          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cpfCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'CPF',
            prefixIcon: Icon(Icons.badge_outlined)),
          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Senha',
            prefixIcon: Icon(Icons.lock_outlined)),
          validator: (v) =>
            v!.length < 6 ? 'Mínimo 6 caracteres' : null,
        ),
      ],
    );
  }

  // ── Step 1 — Sobre as tarifas ─────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.monetization_on,
          size: 48, color: AppTheme.secondary),
        const SizedBox(height: 16),
        const Text('Como funcionam as tarifas',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Sua tarifa é definida automaticamente pela sua localização.',
          style: TextStyle(color: AppTheme.gray)),
        const SizedBox(height: 24),

        // Cards informativos
        _InfoCard(
          icon:  Icons.location_on,
          color: AppTheme.secondary,
          title: 'Tarifa por cidade',
          text:  'Cada cidade tem sua própria tarifa. '
                 'Quando você aceitar uma corrida, a tarifa '
                 'da cidade onde você está será aplicada.',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon:  Icons.account_balance_wallet,
          color: AppTheme.primary,
          title: 'Sistema pré-pago',
          text:  'Você adiciona saldo à sua carteira e a '
                 'taxa de cada corrida é descontada automaticamente. '
                 'O valor da corrida é sempre repassado integralmente.',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon:  Icons.info_outline,
          color: AppTheme.warning,
          title: 'Consulte a tarifa local',
          text:  'Na tela de Suporte do app você pode consultar '
                 'a tarifa exata da sua região a qualquer momento.',
        ),

        const SizedBox(height: 24),

        // Aviso de aprovação
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.secondary.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
              color: AppTheme.secondary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Após o cadastro, envie seus documentos para '
                'começar a receber corridas.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(text,
                style: const TextStyle(
                  fontSize: 13, color: AppTheme.gray)),
            ],
          )),
        ],
      ),
    );
  }
}