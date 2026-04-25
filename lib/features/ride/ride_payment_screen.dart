import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RidePaymentScreen — tela dedicada ao recebimento
//
// Exibida quando status = completed
// Layout limpo: só o valor, método e o slider de confirmação
//
// Rota: /ride-payment/:rideId
// Extras: payMethod, price, passengerName
//
// Fluxo:
//   ride_detail → (completed) → ride_payment → (confirmado) → passenger_rating
// ─────────────────────────────────────────────────────────────────────────────

class RidePaymentScreen extends StatefulWidget {
  final String  rideId;
  final String  payMethod;
  final double  price;
  final String? passengerName;

  const RidePaymentScreen({
    super.key,
    required this.rideId,
    required this.payMethod,
    required this.price,
    this.passengerName,
  });

  @override
  State<RidePaymentScreen> createState() => _RidePaymentScreenState();
}

class _RidePaymentScreenState extends State<RidePaymentScreen>
    with SingleTickerProviderStateMixin {

  bool _confirming = false;
  bool _confirmed  = false;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  IconData get _payIcon => switch (widget.payMethod) {
    'pix'    => Icons.pix,
    'card'   => Icons.credit_card,
    'wallet' => Icons.account_balance_wallet,
    _        => Icons.attach_money,
  };

  String get _payLabel => switch (widget.payMethod) {
    'pix'    => 'PIX',
    'card'   => 'Cartão',
    'wallet' => 'Carteira',
    _        => 'Dinheiro',
  };

  String get _instruction => switch (widget.payMethod) {
    'cash'   => 'Receba o dinheiro em mãos e confirme',
    'pix'    => 'Verifique o PIX no seu banco e confirme',
    'card'   => 'Aguarde a aprovação no cartão e confirme',
    'wallet' => 'Débito na carteira digital — confirme',
    _        => 'Confirme o recebimento para finalizar',
  };

  Future<void> _confirm() async {
    if (_confirming || _confirmed) return;
    setState(() => _confirming = true);
    _pulseCtrl.stop();

    try {
      await ApiClient().dio.put(
        '/rides/${widget.rideId}/status',
        data: {'status': 'payment_confirmed'},
      );

      if (!mounted) return;
      setState(() { _confirming = false; _confirmed = true; });

      // Pequena pausa para o usuário ver o feedback
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        context.go(
          '/ride-rating/${widget.rideId}',
          extra: {
            'passengerName': widget.passengerName,
            'price':         widget.price,
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('Erro ao confirmar. Tente novamente.'),
          backgroundColor: AppTheme.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF059669),
      body: SafeArea(
        child: Column(children: [

          // ── Área principal — valor em destaque ────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Ícone do método de pagamento
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15)),
                  child: Icon(_payIcon,
                    color: Colors.white, size: 36)),

                const SizedBox(height: 16),

                Text(_payLabel,
                  style: TextStyle(
                    color:    Colors.white.withValues(alpha: 0.8),
                    fontSize: 16)),

                const SizedBox(height: 20),

                // Valor — destaque máximo, leve pulsação
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: _confirmed ? 1.0 : _pulseAnim.value,
                    child: child),
                  child: Text(
                    'R\$ ${widget.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      64,
                      fontWeight:    FontWeight.bold,
                      height:        1.0,
                      letterSpacing: -3)),
                ),

                const SizedBox(height: 28),

                // Instrução
                Container(
                  margin:  const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color:    Colors.white,
                      fontSize: 15,
                      height:   1.5)),
                ),
              ],
            ),
          ),

          // ── Painel inferior — slider ───────────────────────────
          Container(
            decoration: const BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color:        Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),

                // Slider de confirmação
                _ConfirmSlider(
                  confirmed:   _confirmed,
                  confirming:  _confirming,
                  onConfirmed: _confirm,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ConfirmSlider — slider simples de uma direção (esquerda → direita)
// thumb começa à esquerda, desliza para confirmar
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmSlider extends StatefulWidget {
  final bool         confirmed;
  final bool         confirming;
  final VoidCallback onConfirmed;

  const _ConfirmSlider({
    required this.confirmed,
    required this.confirming,
    required this.onConfirmed,
  });

  @override
  State<_ConfirmSlider> createState() => _ConfirmSliderState();
}

class _ConfirmSliderState extends State<_ConfirmSlider>
    with SingleTickerProviderStateMixin {

  static const _trackH    = 68.0;
  static const _thumbSize = 60.0;
  static const _pad       = 4.0;
  static const _threshold = 0.80;

  double _pos     = 0.0;
  double _maxDrag = 0.0;
  bool   _done    = false;

  late AnimationController _snapCtrl;
  late Animation<double>   _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  }

  @override
  void dispose() { _snapCtrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(covariant _ConfirmSlider old) {
    super.didUpdateWidget(old);
    if (old.confirming && !widget.confirming && !widget.confirmed) {
      // Erro — reseta
      setState(() { _done = false; _pos = 0.0; });
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.confirming || widget.confirmed || _done) return;
    setState(() => _pos = (_pos + d.delta.dx / _maxDrag).clamp(0.0, 1.0));
  }

  void _onDragEnd(DragEndDetails _) {
    if (widget.confirming || widget.confirmed || _done) return;
    if (_pos >= _threshold) {
      _done = true;
      setState(() => _pos = 1.0);
      widget.onConfirmed();
    } else {
      // Snap de volta
      final start = _pos;
      _snapAnim = Tween<double>(begin: start, end: 0.0).animate(
        CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut))
        ..addListener(() {
          if (mounted) setState(() => _pos = _snapAnim.value);
        });
      _snapCtrl.forward(from: 0);
    }
  }

  Color get _trackBg {
    final t = _pos.clamp(0.0, 1.0);
    return Color.lerp(Colors.grey.shade100, const Color(0xFF059669), t)!;
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = widget.confirmed;

    return LayoutBuilder(builder: (_, c) {
      _maxDrag = c.maxWidth - _thumbSize - (_pad * 2);
      final thumbX    = _pad + _pos * _maxDrag;
      final labelOpacity = (1.0 - _pos * 2.5).clamp(0.0, 1.0);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _trackH,
        decoration: BoxDecoration(
          color:        isConfirmed
              ? const Color(0xFF059669) : _trackBg,
          borderRadius: BorderRadius.circular(_trackH / 2)),
        child: Stack(alignment: Alignment.centerLeft, children: [

          // Label centralizado
          if (!isConfirmed)
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: labelOpacity,
                  child: const Text('Deslize para confirmar',
                    style: TextStyle(
                      color:      Color(0xFF059669),
                      fontWeight: FontWeight.w600,
                      fontSize:   15))))),

          // Setas →→
          Positioned(
            right: 20,
            child: Opacity(
              opacity: labelOpacity,
              child: Row(children: [
                Icon(Icons.chevron_right_rounded,
                  color: const Color(0xFF059669).withValues(alpha: 0.4),
                  size: 22),
                Icon(Icons.chevron_right_rounded,
                  color: const Color(0xFF059669),
                  size: 22),
              ]),
            ),
          ),

          // Feedback de confirmado
          if (isConfirmed)
            const Positioned.fill(
              child: Center(
                child: Text('Recebimento confirmado!',
                  style: TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize:   15)))),

          // Thumb
          Positioned(
            left: isConfirmed ? (_pad + _maxDrag) : thumbX,
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd:    _onDragEnd,
              child: Container(
                width: _thumbSize, height: _thumbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: isConfirmed
                        ? Colors.white
                        : const Color(0xFF059669).withValues(
                            alpha: (_pos * 1.5).clamp(0.2, 1.0)),
                    width: 2.5),
                  boxShadow: [BoxShadow(
                    color:      Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset:     const Offset(0, 3))]),
                child: widget.confirming
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF059669)))
                  : isConfirmed || _done
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF059669), size: 28)
                      : const Icon(Icons.payments_outlined,
                          color: Color(0xFF059669), size: 26),
              ),
            ),
          ),
        ]),
      );
    });
  }
}