import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_theme.dart';
import '../../core/config/api_client.dart';
import '../../core/services/auth_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordCtrl = TextEditingController();
  bool _loading       = false;
  bool _obscure       = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestDeletion() async {
    if (_passwordCtrl.text.isEmpty) {
      _showSnack('Informe sua senha para confirmar.', AppTheme.warning);
      return;
    }

    // Confirmação final
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
          SizedBox(width: 8),
          Text('Confirmar exclusão'),
        ]),
        content: const Text(
          'Tem certeza? Sua conta será excluída em 30 dias.\n\n'
          'Se fizer login antes desse prazo, a exclusão será cancelada automaticamente.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sim, excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.delete(
        '/profile',
        data: {'password': _passwordCtrl.text},
      );

      final scheduledFor = res.data['scheduled_for'] as String? ?? '30 dias';

      if (!mounted) return;

      // Logout e redireciona para login
      await AuthService().logout();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Exclusão agendada'),
            content: Text(
              'Sua conta será excluída em $scheduledFor.\n\n'
              'Você receberá um e-mail de confirmação.\n\n'
              'Se mudar de ideia, basta fazer login antes dessa data.',
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = _parseError(e);
      _showSnack(msg, AppTheme.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _parseError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      return data?['message'] as String? ?? 'Erro ao processar solicitação.';
    } catch (_) {
      return 'Erro ao processar solicitação.';
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
        title: const Text('Excluir conta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Ícone ────────────────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:        AppTheme.danger.withValues(alpha: 0.08),
                  shape:        BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_outlined,
                  size:  56,
                  color: AppTheme.danger,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Título ───────────────────────────────────────
            const Text(
              'Excluir minha conta',
              style: TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.bold,
                color:      AppTheme.dark,
              ),
            ),

            const SizedBox(height: 16),

            // ── Aviso LGPD ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.warning, size: 18),
                    SizedBox(width: 8),
                    Text('Antes de continuar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:      AppTheme.warning,
                      )),
                  ]),
                  const SizedBox(height: 12),
                  _InfoItem(
                    icon: Icons.schedule,
                    text: 'Sua conta ficará em exclusão pendente por 30 dias.',
                  ),
                  _InfoItem(
                    icon: Icons.login,
                    text: 'Se fizer login nesse período, a exclusão é cancelada automaticamente.',
                  ),
                  _InfoItem(
                    icon: Icons.receipt_long,
                    text: 'Histórico de corridas e registros financeiros são mantidos por exigência legal, mas desvinculados dos seus dados pessoais.',
                  ),
                  _InfoItem(
                    icon: Icons.shield_outlined,
                    text: 'Seus dados pessoais (nome, CPF, telefone) serão anonimizados após o prazo.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Senha ────────────────────────────────────────
            const Text(
              'Confirme sua senha para continuar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color:      AppTheme.dark,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller:  _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText:    'Sua senha atual',
                prefixIcon:  const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Botão ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _requestDeletion,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(_loading
                    ? 'Processando...'
                    : 'Solicitar exclusão de conta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Link LGPD ────────────────────────────────────
            Center(
              child: Text(
                'Em conformidade com a LGPD (Lei 13.709/2018)',
                style: TextStyle(
                  fontSize: 11,
                  color:    AppTheme.gray.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Widget auxiliar — item de informação
// ─────────────────────────────────────────────────────────────────
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String   text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.gray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.gray, height: 1.4)),
          ),
        ],
      ),
    );
  }
}