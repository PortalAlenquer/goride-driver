import 'package:flutter/material.dart';
import '../../../core/config/app_theme.dart';


class RideCancelledCard extends StatelessWidget {
  final VoidCallback onDone;
  final String?      reason;

  const RideCancelledCard({
    super.key,
    required this.onDone,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [

      Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color:        AppTheme.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.danger.withValues(alpha: 0.2))),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.danger.withValues(alpha: 0.1)),
            child: const Icon(
              Icons.cancel_outlined,
              color: AppTheme.danger, size: 34)),
          const SizedBox(height: 12),
          const Text('Corrida cancelada',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   18,
              color:      AppTheme.dark)),
          const SizedBox(height: 6),
          Text(
            reason ?? 'Esta corrida foi cancelada.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.gray, fontSize: 14, height: 1.4)),
        ]),
      ),

      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize:     const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
          child: const Text('Voltar ao início',
            style: TextStyle(fontSize: 16)),
        ),
      ),
    ]);
  }
}