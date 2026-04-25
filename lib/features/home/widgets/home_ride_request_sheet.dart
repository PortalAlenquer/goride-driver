import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/widgets/slide_action_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout padrão mercado (Uber/99):
//
//  ┌─────────────────────────────────────┐
//  │  Nova Corrida              [💳 PIX] │
//  │                                     │
//  │         R$ 24,90                    │  ← valor grande
//  │   ★ 4.8  · 127 corridas            │  ← passageiro
//  │   ⚡ Demanda alta 1.5x              │  ← surge (condicional)
//  ├─────────────────────────────────────┤
//  │  [🚗 4 min]  Rua das Flores, 142   │  ← origem + tempo até
//  │       │                             │
//  │  [⏱ 12 min] Av. Paulista, 900      │  ← destino + duração
//  ├─────────────────────────────────────┤
//  │  2,4 km  ·  R$ 2,10/km            │  ← métricas
//  ├─────────────────────────────────────┤
//  │  [Pular] ←← [🚗 contador] →→ [Aceitar] │
//  └─────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

class HomeRideRequestSheet extends StatefulWidget {
  final Map<String, dynamic>    ride;
  final VoidCallback            onAccept;
  final Future<void> Function() onReject;
  final int                     timeoutSeconds;

  const HomeRideRequestSheet({
    super.key,
    required this.ride,
    required this.onAccept,
    required this.onReject,
    this.timeoutSeconds = 20,
  });

  @override
  State<HomeRideRequestSheet> createState() => _HomeRideRequestSheetState();
}

class _HomeRideRequestSheetState extends State<HomeRideRequestSheet> {
  late int _remaining;
  Timer?   _timer;
  bool     _dismissed = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeoutSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      if (_remaining <= 5 && _remaining > 0) HapticFeedback.lightImpact();
      if (_remaining <= 0) { t.cancel(); _autoReject(); }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _autoReject() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    if (Navigator.canPop(context)) Navigator.pop(context);
    widget.onReject();
  }

  void _handleAccept() {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    if (Navigator.canPop(context)) Navigator.pop(context);
    widget.onAccept();
  }

  void _handleReject() {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    if (Navigator.canPop(context)) Navigator.pop(context);
    widget.onReject();
  }

  // ── Helpers de dados ──────────────────────────────────────────

  Map<String, dynamic> get _ride => widget.ride;

  double get _price =>
      double.tryParse(_ride['estimated_price']?.toString() ?? '0') ?? 0.0;

  double get _distKm =>
      double.tryParse(_ride['distance_km']?.toString() ?? '0') ?? 0.0;

  int get _durationMin =>
      int.tryParse(_ride['duration_minutes']?.toString() ?? '0') ?? 0;

  // Tempo estimado até o passageiro (~40% da duração da viagem)
  int get _pickupMin => (_durationMin * 0.4).round().clamp(1, 99);

  // R$/km real da tabela (preferível) ou fallback com divisão
  double get _pricePerKm {
    final real = double.tryParse(_ride['price_per_km']?.toString() ?? '');
    if (real != null && real > 0) return real;
    return _distKm > 0 ? _price / _distKm : 0.0;
  }

  bool get _hasPricePerKm =>
      double.tryParse(_ride['price_per_km']?.toString() ?? '') != null;

  bool get _hasSurge {
    final v = double.tryParse(_ride['surge_multiplier']?.toString() ?? '1') ?? 1.0;
    return v > 1.0;
  }

  double get _surgeMultiplier =>
      double.tryParse(_ride['surge_multiplier']?.toString() ?? '1') ?? 1.0;

  // Passageiro
  Map<String, dynamic>? get _passenger =>
      _ride['passenger'] as Map<String, dynamic>?;

  double get _passengerRating =>
      double.tryParse(_passenger?['rating']?.toString() ?? '5') ?? 5.0;

  int get _passengerRides =>
      int.tryParse(_passenger?['total_rides']?.toString() ?? '0') ?? 0;

  String get _paymentMethod =>
      _ride['payment_method']?.toString() ?? 'cash';

  IconData get _payIcon => switch (_paymentMethod) {
    'pix'    => Icons.pix,
    'card'   => Icons.credit_card,
    'wallet' => Icons.account_balance_wallet,
    _        => Icons.attach_money,
  };

  String get _payLabel => switch (_paymentMethod) {
    'pix'    => 'PIX',
    'card'   => 'Cartão',
    'wallet' => 'Carteira',
    _        => 'Dinheiro',
  };

  // Cor da avaliação do passageiro
  Color get _ratingColor {
    if (_passengerRating >= 4.5) return AppTheme.secondary;
    if (_passengerRating >= 4.0) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
          ),

          Padding(
            padding: EdgeInsets.only(
              left:   20, right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Título + pagamento ───────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Nova Corrida',
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      AppTheme.gray,
                        letterSpacing: 0.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:        AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        Icon(_payIcon, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 5),
                        Text(_payLabel,
                          style: const TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                            color:      AppTheme.primary)),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Valor em destaque ────────────────────────
                Text(
                  'R\$ ${_price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize:   44,
                    fontWeight: FontWeight.bold,
                    color:      AppTheme.dark,
                    height:     1.0,
                    letterSpacing: -1)),

                const SizedBox(height: 10),

                // ── Passageiro: rating + corridas ────────────
                Row(children: [
                  Icon(Icons.star_rounded,
                    color: _ratingColor, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _passengerRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.bold,
                      color:      _ratingColor)),
                  const SizedBox(width: 6),
                  Text('·',
                    style: const TextStyle(
                      color: AppTheme.gray, fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    _passengerRides > 0
                        ? '$_passengerRides corridas'
                        : 'Novo passageiro',
                    style: const TextStyle(
                      fontSize: 14, color: AppTheme.gray)),
                ]),

                // ── Surge (demanda alta) ─────────────────────
                if (_hasSurge) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:        AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt,
                          size: 14, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        Text(
                          'Demanda alta · ${_surgeMultiplier.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.bold,
                            color:      AppTheme.warning)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Rota: Origem ─────────────────────────────
                _RouteRow(
                  isOrigin:  true,
                  address:   _ride['origin_address']?.toString() ?? '—',
                  timeBadge: '$_pickupMin min',
                  badgeColor: AppTheme.primary,
                  badgeIcon:  Icons.directions_car,
                ),

                // Linha conectora
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Column(
                    children: List.generate(3, (_) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      width: 1.5, height: 5,
                      color: Colors.grey.shade300)),
                  ),
                ),

                // ── Rota: Destino ────────────────────────────
                _RouteRow(
                  isOrigin:   false,
                  address:    _ride['destination_address']?.toString() ?? '—',
                  timeBadge:  _durationMin > 0 ? '$_durationMin min' : '—',
                  badgeColor: AppTheme.secondary,
                  badgeIcon:  Icons.access_time,
                ),

                const SizedBox(height: 14),

                // ── Métricas: km · R$/km ─────────────────────
                Row(children: [
                  if (_distKm > 0) ...[
                    const Icon(Icons.straighten,
                      size: 14, color: AppTheme.gray),
                    const SizedBox(width: 4),
                    Text(
                      '${_distKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 13, color: AppTheme.gray)),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.route,
                    size: 14, color: AppTheme.gray),
                  const SizedBox(width: 4),
                  Text(
                    'R\$ ${_pricePerKm.toStringAsFixed(2)}/km'
                    '${_hasPricePerKm ? '' : '*'}',
                    style: const TextStyle(
                      fontSize: 13, color: AppTheme.gray)),
                ]),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // ── Slider ───────────────────────────────────
                RideSlider(
                  confirmLabel: 'Aceitar',
                  rejectLabel:  'Pular',
                  confirmColor: AppTheme.secondary,
                  rejectColor:  AppTheme.gray,
                  thumbIcon:    Icons.directions_car,
                  countdown:    _remaining,
                  onConfirm:    _handleAccept,
                  onReject:     _handleReject,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Linha de rota — origem ou destino com badge de tempo
// ─────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  final bool    isOrigin;
  final String  address;
  final String  timeBadge;
  final Color   badgeColor;
  final IconData badgeIcon;

  const _RouteRow({
    required this.isOrigin,
    required this.address,
    required this.timeBadge,
    required this.badgeColor,
    required this.badgeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        // Indicador de ponto
        Container(
          width: 12, height: 12,
          decoration: isOrigin
            ? BoxDecoration(
                shape:  BoxShape.circle,
                color:  Colors.white,
                border: Border.all(
                  color: AppTheme.primary, width: 2.5))
            : BoxDecoration(
                color:        AppTheme.danger,
                borderRadius: BorderRadius.circular(3)),
        ),

        const SizedBox(width: 12),

        // Endereço — fonte maior para facilitar leitura
        Expanded(
          child: Text(
            address,
            style: const TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w500,
              color:      AppTheme.dark,
              height:     1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        ),

        const SizedBox(width: 8),

        // Badge de tempo
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:        badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 11, color: badgeColor),
              const SizedBox(width: 3),
              Text(
                timeBadge,
                style: TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.bold,
                  color:      badgeColor)),
            ],
          ),
        ),
      ],
    );
  }
}