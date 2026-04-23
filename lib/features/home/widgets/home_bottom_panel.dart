import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class HomeBottomPanel extends StatelessWidget {
  final bool         isOnline;
  final bool         needsVehicle;
  final bool         needsApproval;
  final String       rating;
  final String       balanceLabel;
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow:    [BoxShadow(color: Colors.black12, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Aviso perfil incompleto ───────────────────────────
          if (needsVehicle || needsApproval)
            GestureDetector(
              onTap: () => context.push('/complete-profile'),
              child: Container(
                width:  double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        AppTheme.warning.withValues(alpha: 0.1),
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
                        color:      AppTheme.warning,
                        fontWeight: FontWeight.w600,
                        fontSize:   13))),
                  const Icon(Icons.chevron_right,
                    color: AppTheme.warning, size: 18),
                ]),
              ),
            ),

          // ── Toggle online — botão largo ───────────────────────
          GestureDetector(
            onTap: onToggleOnline,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:   double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color:        isOnline
                    ? AppTheme.secondary
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isOnline ? [BoxShadow(
                  color:      AppTheme.secondary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset:     const Offset(0, 4))] : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // Indicador pulsante quando online
                  if (isOnline)
                    _PulsingDot()
                  else
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color:  Colors.grey.shade400,
                        shape:  BoxShape.circle),
                    ),

                  const SizedBox(width: 12),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize:   18,
                          fontWeight: FontWeight.bold,
                          color:      isOnline
                              ? Colors.white : AppTheme.dark)),
                      Text(
                        isOnline
                          ? 'Buscando corridas...'
                          : 'Toque para ficar online',
                        style: TextStyle(
                          fontSize: 12,
                          color:    isOnline
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppTheme.gray)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot pulsante quando online ────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width:  10, height: 10,
        decoration: BoxDecoration(
          color:  Colors.white.withValues(alpha: _anim.value),
          shape:  BoxShape.circle,
          boxShadow: [BoxShadow(
            color:      Colors.white.withValues(alpha: _anim.value * 0.6),
            blurRadius: 6,
            spreadRadius: 2)],
        ),
      ),
    );
  }
}