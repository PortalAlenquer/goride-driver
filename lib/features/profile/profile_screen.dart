import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = ProfileService();
  final _picker  = ImagePicker();

  UserModel?            _user;
  Map<String, dynamic>? _driver;
  bool _loading = true;
  bool _saving  = false;

  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cpfCtrl   = TextEditingController();

  File?   _avatarFile;
  String? _existingAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cpfCtrl.dispose();
    super.dispose();
  }

  // ── Carregamento ──────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      final result = await _service.loadProfile();
      final user   = result['user']   as UserModel;
      final driver = result['driver'] as Map<String, dynamic>?;
      setState(() {
        _user           = user;
        _driver         = driver;
        _nameCtrl.text  = user.name;
        _emailCtrl.text = user.email;
        _phoneCtrl.text = user.phone;
        _cpfCtrl.text   = user.cpf ?? '';
        if (user.avatar != null && user.avatar!.isNotEmpty) {
          _existingAvatarUrl = _service.storageUrl(user.avatar!);
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Avatar ────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  // ── Salvar ────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    // Captura messenger antes dos awaits — resolve BuildContext async gap
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _service.updateProfile(
        name:  _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        cpf:   _cpfCtrl.text.trim(),
      );

      if (_avatarFile != null) {
        final newUrl = await _service.uploadAvatar(_avatarFile!.path);
        if (newUrl != null && mounted) {
          setState(() {
            _existingAvatarUrl = newUrl;
            _avatarFile        = null;
          });
        }
      }

      messenger.showSnackBar(const SnackBar(
        content: Text('Perfil atualizado!'),
        backgroundColor: AppTheme.secondary,
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Erro ao salvar perfil.'),
        backgroundColor: AppTheme.danger,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────

  Future<void> _logout() async {
    // Captura router antes do await — resolve BuildContext async gap
    final router = GoRouter.of(context);
    await AuthService().logout();
    router.go('/login');
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rating     = _driver?['rating']?.toString()      ?? '5.0';
    final totalRides = _driver?['total_rides']?.toString()  ?? '0';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Meu perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.push('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.danger),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [

                // ── Avatar ───────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor:
                            AppTheme.secondary.withValues(alpha: 0.1),
                          backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!) as ImageProvider
                            : _existingAvatarUrl != null
                              ? CachedNetworkImageProvider(_existingAvatarUrl!)
                              : null,
                          child: (_avatarFile == null &&
                                  _existingAvatarUrl == null)
                            ? Text(
                                (_user?.name ?? 'M')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondary,
                                ))
                            : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Text(_user?.name ?? '',
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Motorista',
                    style: TextStyle(
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    )),
                ),

                const SizedBox(height: 16),

                // ── Stats ────────────────────────────────────
                Row(children: [
                  Expanded(child: _StatCard(
                    icon:  Icons.star,
                    color: AppTheme.warning,
                    label: 'Avaliação',
                    value: rating,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    icon:  Icons.directions_car,
                    color: AppTheme.primary,
                    label: 'Corridas',
                    value: totalRides,
                  )),
                ]),

                const SizedBox(height: 24),

                // ── Campos ───────────────────────────────────
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  enabled: false,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cpfCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CPF',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Botão salvar ─────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary),
                    child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Salvar alterações'),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Menu de opções ───────────────────────────
                _ProfileOption(
                  icon:  Icons.account_balance_wallet_outlined,
                  label: 'Minha carteira',
                  onTap: () => context.push('/wallet'),
                ),
                _ProfileOption(
                  icon:  Icons.directions_car,
                  label: 'Veículo e documentos',
                  onTap: () => context.push('/complete-profile'),
                ),
                _ProfileOption(
                  icon:  Icons.history,
                  label: 'Ganhos',
                  onTap: () => context.push('/earnings'),
                ),
                _ProfileOption(
                  icon:  Icons.history,
                  label: 'Histórico de corridas',
                  onTap: () => context.push('/ride-history'),
                ),
                _ProfileOption(
                  icon:  Icons.payment,
                  label: 'Formas de pagamento aceitas',
                  onTap: () => context.push('/payment-methods'),
                ),
                _ProfileOption(
  icon:  Icons.headset_mic,
  label: 'Suporte',
  onTap: () => context.push('/support'),
),
                _ProfileOption(
                  icon:  Icons.lock_outlined,
                  label: 'Alterar senha',
                  onTap: () => context.push('/change-password'),
                ),
              ],
            ),
          ),
    );
  }
}

// Widgets locais

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.gray)),
            Text(value,
              style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ]),
    );
  }
}

// ── _ProfileOption — cor removida (nunca era passada por nenhum chamador)
class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:  Icon(icon, color: AppTheme.dark),
      title:    Text(label, style: const TextStyle(color: AppTheme.dark)),
      trailing: Icon(Icons.chevron_right,
        color: AppTheme.dark.withValues(alpha: 0.5)),
      onTap: onTap,
    );
  }
}