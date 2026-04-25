import 'package:flutter/material.dart';
import '../../../core/config/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RideStatusStepper — indicador de progresso da corrida
//
// Padrão mercado: círculos pequenos conectados por linha, step atual
// em destaque com label, steps concluídos em verde, futuros em cinza.
// ─────────────────────────────────────────────────────────────────────────────

class RideStatusStepper extends StatelessWidget {
  final String currentStatus;

  const RideStatusStepper({
    super.key,
    required this.currentStatus,
  });

  static const _steps = [
    ('accepted',          'Aceita',      Icons.check_rounded),
    ('driver_arriving',   'A caminho',   Icons.directions_car),
    ('in_progress',       'Em viagem',   Icons.route),
    ('completed',         'Finalizada',  Icons.flag_rounded),
    ('payment_confirmed', 'Pago',        Icons.monetization_on),
  ];

  int get _currentIndex =>
      _steps.indexWhere((s) => s.$1 == currentStatus);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Linha conectora
          final done = (i ~/ 2) < _currentIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color:        done
                      ? AppTheme.secondary : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(1)),
              ),
            ),
          );
        }

        final idx     = i ~/ 2;
        final step    = _steps[idx];
        final done    = idx < _currentIndex;
        final current = idx == _currentIndex;
        final future  = idx > _currentIndex;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Círculo do step
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppTheme.secondary
                    : current
                        ? AppTheme.primary
                        : Colors.grey.shade200,
                boxShadow: current ? [BoxShadow(
                  color:      AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1)] : [],
              ),
              child: Icon(
                done ? Icons.check_rounded : step.$3,
                size:  14,
                color: future
                    ? Colors.grey.shade400
                    : Colors.white),
            ),

            const SizedBox(height: 5),

            // Label
            Text(
              step.$2,
              style: TextStyle(
                fontSize:   9,
                fontWeight: current
                    ? FontWeight.bold : FontWeight.normal,
                color: current
                    ? AppTheme.primary
                    : done
                        ? AppTheme.secondary
                        : AppTheme.gray),
            ),
          ],
        );
      }),
    );
  }
}