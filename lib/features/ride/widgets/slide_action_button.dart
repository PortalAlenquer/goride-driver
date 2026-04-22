import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RideSlider — widget padrão para toda a viagem
//
// Layout:  [ Rejeitar ] ←←  [ thumb ]  →→  [ Confirmar ]
//
// - onReject = null  → sem lado esquerdo, thumb começa à esquerda
// - onReject != null → dois lados, thumb começa no centro
// - countdown > 0    → anel + número no thumb
//
// FIX travamento: didUpdateWidget reseta _done quando busy volta a false,
// garantindo que o slider fique disponível após cada transição de status.
// ─────────────────────────────────────────────────────────────────────────────

class RideSlider extends StatefulWidget {
  final String        confirmLabel;
  final String?       rejectLabel;
  final VoidCallback  onConfirm;
  final VoidCallback? onReject;
  final Color         confirmColor;
  final Color         rejectColor;
  final IconData      thumbIcon;
  final int           countdown;
  final bool          busy;

  const RideSlider({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.rejectLabel,
    this.onReject,
    this.confirmColor = AppTheme.secondary,
    this.rejectColor  = AppTheme.danger,
    this.thumbIcon    = Icons.directions_car,
    this.countdown    = 0,
    this.busy         = false,
  });

  @override
  State<RideSlider> createState() => _RideSliderState();
}

class _RideSliderState extends State<RideSlider>
    with SingleTickerProviderStateMixin {

  static const _trackH      = 72.0;
  static const _thumbSize   = 64.0;
  static const _sidePad     = 4.0;
  static const _confirmZone = 0.80;
  static const _rejectZone  = 0.20;

  late double _pos;
  bool        _done    = false;
  double      _maxDrag = 0;

  double get _startPos => widget.onReject != null ? 0.5 : 0.0;

  late AnimationController _snapCtrl;
  late Animation<double>   _snapAnim;

  @override
  void initState() {
    super.initState();
    _pos      = _startPos;
    _snapCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 280),
    );
  }

  // Reseta o slider quando a operação termina (busy: true → false)
  // Isso evita o travamento após uma transição de status bem-sucedida
  @override
  void didUpdateWidget(covariant RideSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy && !widget.busy) {
      setState(() {
        _done = false;
        _pos  = _startPos;
      });
    }
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  // ── Drag ──────────────────────────────────────────────────────

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.busy || _done) return;
    final next = _pos + d.delta.dx / _maxDrag;
    setState(() => _pos = next.clamp(0.0, 1.0));
  }

  void _onDragEnd(DragEndDetails _) {
    if (widget.busy || _done) return;
    if (_pos >= _confirmZone) {
      _confirm();
    } else if (widget.onReject != null && _pos <= _rejectZone) {
      _reject();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    final start = _pos;
    _snapAnim = Tween<double>(begin: start, end: _startPos).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut),
    )..addListener(() {
      if (mounted) setState(() => _pos = _snapAnim.value);
    });
    _snapCtrl.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _confirm() {
    if (_done) return;
    _done = true;
    setState(() => _pos = 1.0);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) widget.onConfirm();
    });
  }

  void _reject() {
    if (_done || widget.onReject == null) return;
    _done = true;
    setState(() => _pos = 0.0);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) widget.onReject!();
    });
  }

  // ── Cores dinâmicas ───────────────────────────────────────────

  Color get _trackColor {
    if (_pos > _startPos) {
      final t = ((_pos - _startPos) / (1.0 - _startPos)).clamp(0.0, 1.0);
      return Color.lerp(Colors.grey.shade200, widget.confirmColor, t)!;
    } else if (widget.onReject != null && _startPos > 0) {
      final t = ((_startPos - _pos) / _startPos).clamp(0.0, 1.0);
      return Color.lerp(Colors.grey.shade200, widget.rejectColor, t)!;
    }
    return Colors.grey.shade200;
  }

  Color get _borderColor {
    if (_pos >= 0.7) return widget.confirmColor;
    if (widget.onReject != null && _pos <= 0.3) return widget.rejectColor;
    return Colors.grey.shade300;
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasReject    = widget.onReject != null;
    final rightOpacity = _startPos < 1.0
        ? ((_pos - _startPos) / (1.0 - _startPos)).clamp(0.0, 1.0)
        : 0.0;
    final leftOpacity  = hasReject && _startPos > 0
        ? ((_startPos - _pos) / _startPos).clamp(0.0, 1.0)
        : 0.0;

    return LayoutBuilder(builder: (_, constraints) {
      _maxDrag = constraints.maxWidth - _thumbSize - (_sidePad * 2);
      final thumbX = _sidePad + _pos * _maxDrag;

      return SizedBox(
        height: _trackH,
        child: Stack(
          alignment: Alignment.center,
          children: [

            // ── Track ─────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              height: _trackH,
              decoration: BoxDecoration(
                color:        _trackColor,
                borderRadius: BorderRadius.circular(_trackH / 2),
                boxShadow: [BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.07),
                  blurRadius: 8)],
              ),
            ),

            // ── Lado esquerdo — Rejeitar ───────────────────────
            if (hasReject)
              Positioned(
                left: 14,
                child: GestureDetector(
                  onTap: widget.busy ? null : _reject,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity:  (1.0 - rightOpacity).clamp(0.4, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 22,
                          color: leftOpacity > 0.5
                              ? Colors.white : widget.rejectColor),
                        const SizedBox(height: 2),
                        Text(widget.rejectLabel ?? 'Recusar',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: leftOpacity > 0.5
                                ? Colors.white : widget.rejectColor)),
                      ],
                    ),
                  ),
                ),
              ),

            // Setas ←← ao arrastar esquerda
            if (hasReject)
              Positioned(
                left: 70,
                child: Opacity(
                  opacity: leftOpacity,
                  child: Row(children: [
                    Icon(Icons.chevron_left_rounded,
                      color: widget.rejectColor.withValues(alpha: 0.5),
                      size: 20),
                    Icon(Icons.chevron_left_rounded,
                      color: widget.rejectColor, size: 20),
                  ]),
                ),
              ),

            // Setas →→ ao arrastar direita
            Positioned(
              right: 70,
              child: Opacity(
                opacity: rightOpacity,
                child: Row(children: [
                  Icon(Icons.chevron_right_rounded,
                    color: widget.confirmColor.withValues(alpha: 0.5),
                    size: 20),
                  Icon(Icons.chevron_right_rounded,
                    color: widget.confirmColor, size: 20),
                ]),
              ),
            ),

            // ── Lado direito — Confirmar ───────────────────────
            Positioned(
              right: 14,
              child: GestureDetector(
                onTap: widget.busy ? null : _confirm,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity:  (1.0 - leftOpacity).clamp(0.4, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 22,
                        color: rightOpacity > 0.5
                            ? Colors.white : widget.confirmColor),
                      const SizedBox(height: 2),
                      Text(widget.confirmLabel,
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: rightOpacity > 0.5
                              ? Colors.white : widget.confirmColor)),
                    ],
                  ),
                ),
              ),
            ),

            // ── Thumb arrastável ───────────────────────────────
            Positioned(
              left: thumbX,
              child: GestureDetector(
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd:    _onDragEnd,
                child: Container(
                  width: _thumbSize, height: _thumbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: _borderColor, width: 2.5),
                    boxShadow: [BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset:     const Offset(0, 3))],
                  ),
                  child: widget.busy
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: widget.confirmColor))
                    : _done
                        ? Icon(
                            _pos >= 0.5
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: _pos >= 0.5
                                ? widget.confirmColor
                                : widget.rejectColor,
                            size: 28)
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              if (widget.countdown > 0)
                                SizedBox(
                                  width:  _thumbSize - 10,
                                  height: _thumbSize - 10,
                                  child:  CircularProgressIndicator(
                                    value:           widget.countdown / 20,
                                    strokeWidth:     3,
                                    backgroundColor: Colors.grey.shade200,
                                    color: widget.countdown <= 5
                                        ? AppTheme.danger
                                        : widget.confirmColor,
                                  ),
                                ),
                              widget.countdown > 0
                                  ? Text('${widget.countdown}',
                                      style: const TextStyle(
                                        fontSize:   16,
                                        fontWeight: FontWeight.bold,
                                        color:      AppTheme.dark))
                                  : Icon(widget.thumbIcon,
                                      color: AppTheme.dark, size: 26),
                            ],
                          ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}