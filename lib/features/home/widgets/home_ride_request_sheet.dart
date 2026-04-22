import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/widgets/slide_action_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final ride     = widget.ride;
    final price    = ride['estimated_price'];
    final dist     = ride['distance_km'];
    final duration = ride['duration_minutes'];
    final feeType  = ride['fee_type'] ?? 'percentage';
    final feeVal   = double.tryParse(ride['fee_value']?.toString() ?? '0') ?? 0.0;
    final priceD   = double.tryParse(price?.toString() ?? '0') ?? 0.0;
    final fee      = feeType == 'percentage' ? priceD * (feeVal / 100) : feeVal;
    final netPrice = priceD;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          // ── Header ─────────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.directions_car,
                color: AppTheme.secondary, size: 28)),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nova corrida!',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Deslize para aceitar',
                  style: TextStyle(color: AppTheme.gray, fontSize: 13)),
              ],
            )),
          ]),

          const SizedBox(height: 16),

          // ── Card de valores ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.2))),
            child: Column(children: [
              Row(children: [
                Expanded(child: _ValueCard(
                  label: 'Valor bruto',
                  value: 'R\$ ${priceD.toStringAsFixed(2)}',
                  color: AppTheme.dark,
                  large: true)),
                Container(
                  width: 1, height: 40,
                  color: Colors.grey.shade200),
                Expanded(child: _ValueCard(
                  label: 'Distância',
                  value: dist != null
                    ? '${double.parse(dist.toString()).toStringAsFixed(1)} km'
                    : '—',
                  color: AppTheme.primary,
                  icon: Icons.route)),
              ]),
              const Divider(height: 20),
              Row(children: [
                Expanded(child: _ValueCard(
                  label: 'Taxa plataforma',
                  value: '- R\$ ${fee.toStringAsFixed(2)}',
                  color: AppTheme.danger,
                  icon: Icons.remove_circle_outline)),
                Container(
                  width: 1, height: 40,
                  color: Colors.grey.shade200),
                Expanded(child: _ValueCard(
                  label: 'Tempo estimado',
                  value: duration != null ? '$duration min' : '—',
                  color: AppTheme.warning,
                  icon: Icons.access_time)),
              ]),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Você recebe:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('R\$ ${netPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   22,
                      color:      AppTheme.secondary)),
                ],
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Endereços ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.my_location,
                  color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  ride['origin_address'] ?? '—',
                  style:    const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
              ]),
              const Divider(height: 12),
              Row(children: [
                const Icon(Icons.location_on,
                  color: AppTheme.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  ride['destination_address'] ?? '—',
                  style:    const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // ── RideSlider: Pular | thumb+countdown | Aceitar ─
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _ValueCard extends StatelessWidget {
  final String   label;
  final String   value;
  final Color    color;
  final IconData? icon;
  final bool     large;

  const _ValueCard({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.gray)),
          const SizedBox(height: 4),
          Row(children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
            ],
            Text(value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   large ? 18 : 14,
                color:      color)),
          ]),
        ],
      ),
    );
  }
}