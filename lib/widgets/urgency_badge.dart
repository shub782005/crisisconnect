import 'package:flutter/material.dart';
 
class UrgencyBadge extends StatelessWidget {
  final String level; // high, medium, low
  final bool large;
 
  const UrgencyBadge({super.key, required this.level, this.large = false});
 
  @override
  Widget build(BuildContext context) {
    final color = _color();
    final size = large ? 14.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            level.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
 
  Color _color() {
    switch (level.toLowerCase()) {
      case 'high':   return const Color(0xFFE53935);
      case 'medium': return const Color(0xFFFB8C00);
      case 'low':    return const Color(0xFF43A047);
      default:       return const Color(0xFFFB8C00);
    }
  }
}
 