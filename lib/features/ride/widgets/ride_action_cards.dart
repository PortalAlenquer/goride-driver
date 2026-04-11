import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ── Confirmação de pagamento ──────────────────────────────────────

class RidePaymentConfirmCard extends StatelessWidget {
  final String payMethod;
  final double price;
  final VoidCallback onConfirm;
  final bool busy;

  const RidePaymentConfirmCard({
    super.key,
    required this.payMethod,
    required this.price,
    required this.onConfirm,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = payMethod == 'cash';
    final isPix  = payMethod == 'pix';

    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              isCash ? Icons.attach_money
                : isPix ? Icons.pix
                : Icons.credit_card,
              color: Colors.green.shade700, size: 28),
            const SizedBox(width: 10),
            Text('R\$ ${price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700)),
          ]),
          const SizedBox(height: 8),
          Text(
            isCash
              ? 'Receba o dinheiro do passageiro e confirme.'
              : isPix
                ? 'Verifique o PIX recebido e confirme.'
                : 'Pagamento via cartão — confirme o recebimento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.green.shade800)),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: busy ? null : onConfirm,
          icon: busy
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle, size: 22),
          label: const Text('Confirmar recebimento',
            style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ]);
  }
}

// ── Corrida cancelada ─────────────────────────────────────────────

class RideCancelledCard extends StatelessWidget {
  final VoidCallback onDone;
  const RideCancelledCard({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3))),
        child: const Column(children: [
          Icon(Icons.cancel, color: AppTheme.danger, size: 48),
          SizedBox(height: 8),
          Text('Corrida cancelada',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.danger)),
          SizedBox(height: 4),
          Text('O passageiro cancelou esta corrida.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.gray, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondary,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
          child: const Text('Voltar ao início',
            style: TextStyle(fontSize: 16)),
        ),
      ),
    ]);
  }
}

// ── Corrida concluída com sucesso ─────────────────────────────────

class RideSuccessCard extends StatelessWidget {
  final VoidCallback onDone;
  const RideSuccessCard({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200)),
        child: Column(children: [
          Icon(Icons.check_circle,
            color: Colors.green.shade600, size: 48),
          const SizedBox(height: 8),
          const Text('Corrida concluída!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Pagamento confirmado com sucesso.',
            style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondary,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
          child: const Text('Voltar ao início',
            style: TextStyle(fontSize: 16)),
        ),
      ),
    ]);
  }
}