import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_theme.dart';

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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Aviso perfil incompleto ───────────────────────────
          if (needsVehicle || needsApproval)
            GestureDetector(
              onTap: () => context.push('/complete-profile'),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
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
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.warning, size: 18),
                  ],
                ),
              ),
            ),

          // ── Toggle online — botão largo ───────────────────────
          GestureDetector(
            onTap: onToggleOnline,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isOnline ? AppTheme.secondary : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
                boxShadow: isOnline
                    ? [
                        BoxShadow(
                          color: AppTheme.secondary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                 

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOnline)
                        const _PulsingText(
                          text: 'Buscando',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      else
                        Text(
                          'Conectar',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dark,
                          ),
                        ),
                      Text(
                        isOnline
                            ? 'Procurando novas corridas...'
                            : 'Toque para aceitar corridas',
                        style: TextStyle(
                          fontSize: 14,
                          color: isOnline
                              ? const Color.fromARGB(255, 255, 255, 255)
                              : AppTheme.gray,
                        ),
                      ),
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

// ── Widget de Texto Pulsante ──────────────────────────────────────

class _PulsingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _PulsingText({required this.text, required this.style});

  @override
  State<_PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<_PulsingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _opacityAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnim = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}

// ── Dot pulsante ──────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: _anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 2,
            )
          ],
        ),
      ),
    );
  }
}