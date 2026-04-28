import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants/app_colors.dart';

class MapMarkerService {
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Custom pin: urgency color + type letter + priority arc ring
  static Future<BitmapDescriptor> buildNeedMarker({
    required String urgencyLevel,
    required String needType,
    required double priorityScore,
    bool isSelected = false,
  }) async {
    final cacheKey = '$urgencyLevel-$needType-$isSelected';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final color = _urgencyColor(urgencyLevel);
    final letter = needType.isNotEmpty ? needType[0].toUpperCase() : 'N';
    final size = isSelected ? 72.0 : 52.0;
    final r = size * 0.38;
    final cx = size / 2;
    final cy = size * 0.42;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Drop shadow
    canvas.drawCircle(
      Offset(cx, cy + 2),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Pin body
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.5 : 2.5,
    );

    // Priority arc
    if (priorityScore > 0.05) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -1.5708,
        6.2832 * priorityScore,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Letter
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: isSelected ? 22 : 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    // Tail
    final tail = Path()
      ..moveTo(cx - 5, cy + r - 2)
      ..lineTo(cx, size - 4)
      ..lineTo(cx + 5, cy + r - 2)
      ..close();
    canvas.drawPath(tail, Paint()..color = color);
    canvas.drawPath(
      tail,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.5 : 2.5,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Teal 'V' circle for volunteers
  static Future<BitmapDescriptor> buildVolunteerMarker() async {
    const cacheKey = 'volunteer';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    const size = 38.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 2,
      Paint()..color = AppColors.secondary,
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'V',
        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(size / 2 - tp.width / 2, size / 2 - tp.height / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  static Color _urgencyColor(String level) {
    return AppColors.urgencyColor(level);
  }

  static void clearCache() => _cache.clear();
}
