import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class HomeBottomPanel extends StatelessWidget {
  final bool isOnline;
  final bool needsVehicle;
  final bool needsApproval;
  final String rating;
  final String balanceLabel;
  final VoidCallback onToggleOnline;

  const HomeBottomPanel({
    super.key,
    required this.isOnline,
    required this.needsVehicle,
    required this.needsApproval,
    required this.rating,
    required this.balanceLabel,
    required this.onToggleOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Aviso de perfil incompleto
          if (needsVehicle || needsApproval)
            GestureDetector(
              onTap: () => context.go('/complete-profile'),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber,
                    color: AppTheme.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      needsVehicle
                        ? 'Complete seu perfil: adicione seu veículo e documentos.'
                        : 'Seu cadastro está em análise. Aguarde aprovação.',
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13))),
                  const Icon(Icons.chevron_right,
                    color: AppTheme.warning, size: 18),
                ]),
              ),
            ),

          // Toggle online
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'Você está online' : 'Você está offline',
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    isOnline
                      ? 'Aguardando corridas...'
                      : 'Ative para receber corridas',
                    style: const TextStyle(
                      color: AppTheme.gray, fontSize: 13)),
                ],
              ),
              Switch(
                value: isOnline,
                onChanged: (_) => onToggleOnline(),
                activeThumbColor: AppTheme.secondary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stats
          Row(children: [
            Expanded(child: _StatCard(
              icon:  Icons.star,
              color: AppTheme.warning,
              label: 'Avaliação',
              value: rating,
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => context.go('/wallet'),
              child: _StatCard(
                icon:  Icons.account_balance_wallet,
                color: AppTheme.secondary,
                label: 'Saldo',
                value: balanceLabel,
              ),
            )),
          ]),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: const TextStyle(
                fontSize: 11, color: AppTheme.gray)),
            Text(value,
              style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ]),
    );
  }
}