import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/ride_model.dart';

class RidePassengerCard extends StatelessWidget {
  final RidePassenger? passenger;
  final String payLabel;
  final double price;
  final String? originAddress;
  final String? destinationAddress;
  final bool canChat;
  final VoidCallback? onChatTap;
  final Stream<int>? unreadStream;

  const RidePassengerCard({
    super.key,
    required this.passenger,
    required this.payLabel,
    required this.price,
    this.originAddress,
    this.destinationAddress,
    required this.canChat,
    this.onChatTap,
    this.unreadStream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Linha superior: avatar + nome + chat + pagamento ──
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Text(
                (passenger?.name ?? 'P')[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(passenger?.name ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const Text('Passageiro',
                  style: TextStyle(fontSize: 12, color: AppTheme.gray)),
              ],
            )),

            // Botão chat com badge
            if (canChat && onChatTap != null)
              StreamBuilder<int>(
                stream: unreadStream,
                builder: (_, snap) {
                  final unread = snap.data ?? 0;
                  return GestureDetector(
                    onTap: onChatTap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.chat_bubble_outline,
                            color: AppTheme.primary, size: 18),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: -4, top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppTheme.danger,
                                shape: BoxShape.circle),
                              child: Text(
                                unread > 9 ? '9+' : '$unread',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(width: 8),

            // Forma de pagamento + valor
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text(payLabel,
                  style: const TextStyle(
                    fontSize: 11, color: AppTheme.gray)),
                Text('R\$ ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary)),
              ]),
            ),
          ]),

          // ── Endereços ─────────────────────────────────────────
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(children: [
            const Icon(Icons.my_location,
              color: AppTheme.primary, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(
              originAddress ?? '—',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on,
              color: AppTheme.danger, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(
              destinationAddress ?? '—',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ),
    );
  }
}