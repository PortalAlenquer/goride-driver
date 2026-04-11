import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HomeHeatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const HomeHeatChip({
    super.key,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.grey.shade300),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
        ),
        child: Row(children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: active ? color : Colors.grey.shade400,
              shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? color : AppTheme.gray)),
        ]),
      ),
    );
  }
}