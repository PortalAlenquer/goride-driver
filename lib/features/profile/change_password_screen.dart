import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading  = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _obscure3 = true;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient().dio.put('/profile/password', data: {
        'current_password':      _currentCtrl.text,
        'password':              _newCtrl.text,
        'password_confirmation': _confirmCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha alterada com sucesso!'),
            backgroundColor: AppTheme.secondary,
          ),
        );
        context.go('/profile');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha atual incorreta.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Alterar senha'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.lock_outlined,
                size: 48, color: AppTheme.secondary),
              const SizedBox(height: 16),
              const Text('Alterar senha',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Mínimo 6 caracteres.',
                style: TextStyle(color: AppTheme.gray)),
              const SizedBox(height: 32),
              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: 'Senha atual',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1
                      ? Icons.visibility : Icons.visibility_off),
                    onPressed: () =>
                      setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                validator: (v) =>
                  v!.isEmpty ? 'Informe a senha atual' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newCtrl,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2
                      ? Icons.visibility : Icons.visibility_off),
                    onPressed: () =>
                      setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                validator: (v) =>
                  v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscure3,
                decoration: InputDecoration(
                  labelText: 'Confirmar nova senha',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure3
                      ? Icons.visibility : Icons.visibility_off),
                    onPressed: () =>
                      setState(() => _obscure3 = !_obscure3),
                  ),
                ),
                validator: (v) =>
                  v != _newCtrl.text ? 'Senhas não coincidem' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary),
                child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Salvar nova senha'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}