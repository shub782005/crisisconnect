import 'package:flutter/material.dart';

class AppColors {
  // Urgency Colors (judges will notice these)
  static const Color urgencyHigh   = Color(0xFFE53935); // Red
  static const Color urgencyMedium = Color(0xFFFB8C00); // Orange
  static const Color urgencyLow    = Color(0xFF43A047); // Green

  // Brand Colors
  static const Color primary       = Color(0xFF1565C0); // Deep Blue
  static const Color primaryLight  = Color(0xFF1E88E5);
  static const Color secondary     = Color(0xFF00897B); // Teal
  static const Color background    = Color(0xFFF5F7FA);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);

  // Status Colors
  static const Color pending    = Color(0xFFFB8C00);
  static const Color assigned   = Color(0xFF1E88E5);
  static const Color inProgress = Color(0xFF7B1FA2);
  static const Color completed  = Color(0xFF43A047);

  // Map pin colors match urgency
  static Color urgencyColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':   return urgencyHigh;
      case 'medium': return urgencyMedium;
      case 'low':    return urgencyLow;
      default:       return urgencyMedium;
    }
  }
}