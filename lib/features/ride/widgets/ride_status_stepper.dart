import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class RideStatusStepper extends StatelessWidget {
  final String currentStatus;

  const RideStatusStepper({
    super.key,
    required this.currentStatus,
  });

  static const _steps = [
    ('accepted',          'Aceita',     Icons.check),
    ('driver_arriving',   'A caminho',  Icons.directions_car),
    ('in_progress',       'Em viagem',  Icons.route),
    ('completed',         'Finalizada', Icons.flag),
    ('payment_confirmed', 'Pago',       Icons.monetization_on),
  ];

  int get _currentIndex =>
    _steps.indexWhere((s) => s.$1 == currentStatus);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < _currentIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: done ? AppTheme.secondary : Colors.grey.shade200,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final step    = _steps[stepIndex];
        final done    = stepIndex < _currentIndex;
        final current = stepIndex == _currentIndex;

        return Column(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done || current
                ? (current ? AppTheme.secondary : Colors.green)
                : Colors.grey.shade200,
            ),
            child: Icon(step.$3,
              size: 16,
              color: done || current
                ? Colors.white
                : Colors.grey.shade400),
          ),
          const SizedBox(height: 4),
          Text(step.$2,
            style: TextStyle(
              fontSize: 9,
              color: current ? AppTheme.secondary : AppTheme.gray,
              fontWeight:
                current ? FontWeight.bold : FontWeight.normal)),
        ]);
      }),
    );
  }
}