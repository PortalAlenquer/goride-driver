import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/ride_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RidePassengerCard — layout padrão Machine/Uber/99
//
//  ┌──────────────────────────────────────┐
//  │  R$ 24,90          [💳 PIX]          │  ← valor + pagamento
//  ├──────────────────────────────────────┤
//  │  [foto/avatar]  ★ 4.9 · 243 corridas │
//  │  Maria Silva            [💬 chat]    │
//  ├──────────────────────────────────────┤
//  │  ○ Rua das Palmeiras, 142            │
//  │  │                                   │
//  │  ■ Av. Presidente Vargas, 900        │
//  └──────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

class RidePassengerCard extends StatelessWidget {
  final RidePassenger? passenger;
  final String         payLabel;
  final double         price;
  final String?        originAddress;
  final String?        destinationAddress;
  final bool           canChat;
  final VoidCallback?  onChatTap;
  final Stream<int>?   unreadStream;
  final double?        passengerRating;
  final int?           passengerRides;

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
    this.passengerRating,
    this.passengerRides,
  });

  Color get _ratingColor {
    final r = passengerRating ?? 5.0;
    if (r >= 4.5) return AppTheme.secondary;
    if (r >= 4.0) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    final rating = passengerRating ?? 5.0;
    final rides  = passengerRides ?? 0;

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color:      Colors.black.withValues(alpha: 0.06),
          blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.min,
        children: [

          // ── Linha 1: Valor + forma de pagamento ───────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // Valor da corrida em destaque
                Text(
                  'R\$ ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize:      26,
                    fontWeight:    FontWeight.bold,
                    color:         AppTheme.dark,
                    letterSpacing: -0.5,
                    height:        1.0)),

                const Spacer(),

                // Forma de pagamento
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:        AppTheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_payIcon, size: 13, color: AppTheme.secondary),
                      const SizedBox(width: 5),
                      Text(payLabel,
                        style: const TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                          color:      AppTheme.secondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // ── Linha 2: Passageiro + classificação + chat ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // Avatar
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withValues(alpha: 0.1)),
                  child: Center(
                    child: Text(
                      (passenger?.name ?? 'P')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.bold,
                        color:      AppTheme.primary))),
                ),

                const SizedBox(width: 12),

                // Nome + rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.star_rounded,
                          size: 15, color: _ratingColor),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.bold,
                            color:      _ratingColor)),
                        const SizedBox(width: 6),
                        Text('·',
                          style: const TextStyle(
                            color: AppTheme.gray, fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          rides > 0
                              ? '$rides corridas'
                              : 'Novo passageiro',
                          style: const TextStyle(
                            fontSize: 13, color: AppTheme.gray)),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        passenger?.name ?? '—',
                        style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w600,
                          color:      AppTheme.dark)),
                    ],
                  ),
                ),

                // Chat com badge
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:        AppTheme.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10)),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppTheme.primary, size: 20)),
                            if (unread > 0)
                              Positioned(
                                right: -4, top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.danger,
                                    shape: BoxShape.circle),
                                  child: Text(
                                    unread > 9 ? '9+' : '$unread',
                                    style: const TextStyle(
                                      fontSize:   9,
                                      color:      Colors.white,
                                      fontWeight: FontWeight.bold)))),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // ── Endereços ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(children: [

              // Origem
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        shape:  BoxShape.circle,
                        color:  Colors.white,
                        border: Border.all(
                          color: AppTheme.primary, width: 2.5))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      originAddress ?? '—',
                      style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w500,
                        color:      AppTheme.dark,
                        height:     1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
                ],
              ),

              // Linha conectora
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  children: List.generate(3, (_) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 1.5, height: 5,
                    color: Colors.grey.shade300))),
              ),

              // Destino
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color:        AppTheme.danger,
                        borderRadius: BorderRadius.circular(3)))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destinationAddress ?? '—',
                      style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w500,
                        color:      AppTheme.dark,
                        height:     1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }

  IconData get _payIcon => switch (payLabel.toLowerCase()) {
    'pix'     => Icons.pix,
    'cartão'  => Icons.credit_card,
    'carteira' => Icons.account_balance_wallet,
    _         => Icons.attach_money,
  };
}