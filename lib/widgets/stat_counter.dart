import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Animated counting stat widget — counts up from 0 to [value]
class StatCounter extends StatefulWidget {
  final int value;
  final String label;
  final String? prefix;
  final String? suffix;
  final Color color;
  final double fontSize;
  final Duration duration;
  final IconData? icon;

  const StatCounter({
    super.key,
    required this.value,
    required this.label,
    this.prefix,
    this.suffix,
    this.color = AppColors.primary,
    this.fontSize = 28,
    this.duration = const Duration(milliseconds: 1200),
    this.icon,
  });

  @override
  State<StatCounter> createState() => _StatCounterState();
}

class _StatCounterState extends State<StatCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(StatCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final displayValue = (_anim.value * widget.value).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: widget.color, size: 20),
              const SizedBox(height: 4),
            ],
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
                children: [
                  if (widget.prefix != null)
                    TextSpan(
                      text: widget.prefix,
                      style: TextStyle(
                        fontSize: widget.fontSize * 0.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  TextSpan(text: _format(displayValue)),
                  if (widget.suffix != null)
                    TextSpan(
                      text: widget.suffix,
                      style: TextStyle(
                        fontSize: widget.fontSize * 0.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
