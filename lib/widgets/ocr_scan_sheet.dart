import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_colors.dart';
import '../services/ocr_service.dart';

/// Callback when OCR succeeds — caller auto-fills form fields
typedef OnOCRSuccess = void Function(OCRResult result);

/// Show the OCR camera/gallery sheet as a bottom sheet.
/// Usage:
///   showOCRScanSheet(context, onSuccess: (result) { ... });
void showOCRScanSheet(BuildContext context, {required OnOCRSuccess onSuccess}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _OCRScanSheet(onSuccess: onSuccess),
  );
}

class _OCRScanSheet extends StatefulWidget {
  final OnOCRSuccess onSuccess;
  const _OCRScanSheet({required this.onSuccess});

  @override
  State<_OCRScanSheet> createState() => _OCRScanSheetState();
}

enum _SheetState { picking, scanning, result, error }

class _OCRScanSheetState extends State<_OCRScanSheet>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();

  _SheetState _state = _SheetState.picking;
  File? _imageFile;
  OCRResult? _result;
  String _errorMsg = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (xFile == null) return;

    setState(() {
      _imageFile = File(xFile.path);
      _state = _SheetState.scanning;
    });

    try {
      final result = await OCRService.extractFromImage(_imageFile!);
      setState(() {
        _result = result;
        _state = _SheetState.result;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _state = _SheetState.error;
      });
    }
  }

  void _accept() {
    widget.onSuccess(_result!);
    Navigator.pop(context);
  }

  void _retry() {
    setState(() {
      _state = _SheetState.picking;
      _imageFile = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.document_scanner,
                color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Document Scanner',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16, color: AppColors.textPrimary)),
                  Text('Auto-fills form from photo or document',
                    style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(height: 24),

        // Content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildBody(),
        ),

        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _SheetState.picking:
        return _PickerView(onPick: _pickImage);
      case _SheetState.scanning:
        return _ScanningView(imageFile: _imageFile!, pulse: _pulseAnim);
      case _SheetState.result:
        return _ResultView(
          result: _result!,
          imageFile: _imageFile!,
          onAccept: _accept,
          onRetry: _retry,
        );
      case _SheetState.error:
        return _ErrorView(message: _errorMsg, onRetry: _retry);
    }
  }
}

// ── Source picker ────────────────────────────────────────────────────────────
class _PickerView extends StatelessWidget {
  final void Function(ImageSource) onPick;
  const _PickerView({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(children: [
        // Illustration
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
              style: BorderStyle.solid),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome,
                size: 36, color: AppColors.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              const Text('Point at any document, notice,\nor handwritten report',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // Supported formats row
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FormatChip(icon: Icons.edit_note,      label: 'Handwritten'),
            _FormatChip(icon: Icons.print,          label: 'Printed'),
            _FormatChip(icon: Icons.phone_android,  label: 'Screenshots'),
            _FormatChip(icon: Icons.landscape,      label: 'Scene'),
          ],
        ),
        const SizedBox(height: 20),
        // Buttons
        Row(children: [
          Expanded(
            child: _SourceButton(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              subtitle: 'Scan with camera',
              color: AppColors.primary,
              onTap: () => onPick(ImageSource.camera),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SourceButton(
              icon: Icons.photo_library,
              label: 'Gallery',
              subtitle: 'Choose existing',
              color: AppColors.secondary,
              onTap: () => onPick(ImageSource.gallery),
            ),
          ),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FormatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(
          fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SourceButton({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

// ── Scanning animation ──────────────────────────────────────────────────────
class _ScanningView extends StatelessWidget {
  final File imageFile;
  final Animation<double> pulse;
  const _ScanningView({required this.imageFile, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(children: [
        // Image preview with scan overlay
        Stack(alignment: Alignment.center, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              imageFile,
              height: 160, width: double.infinity, fit: BoxFit.cover),
          ),
          // Scan overlay
          Container(
            height: 160, width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12)),
          ),
          Column(children: [
            ScaleTransition(
              scale: pulse,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome,
                  color: AppColors.primary, size: 28),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Gemini AI is reading the image...',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ]),
        const SizedBox(height: 20),
        // Progress steps
        const _ScanStep(icon: Icons.image_search, label: 'Reading image content',    done: true),
        const SizedBox(height: 8),
        const _ScanStep(icon: Icons.manage_search, label: 'Extracting text (OCR)',   done: true),
        const SizedBox(height: 8),
        const _ScanStep(icon: Icons.auto_awesome,  label: 'Parsing relief need data', done: false),
        const SizedBox(height: 16),
        const LinearProgressIndicator(
          backgroundColor: Color(0xFFE3F0FF),
          color: AppColors.primary,
          minHeight: 4,
        ),
      ]),
    );
  }
}

class _ScanStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  const _ScanStep({required this.icon, required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 16,
        color: done ? AppColors.urgencyLow : AppColors.textSecondary),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
        fontSize: 13,
        color: done ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: done ? FontWeight.w500 : FontWeight.normal)),
    ]);
  }
}

// ── Result view ──────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final OCRResult result;
  final File imageFile;
  final VoidCallback onAccept;
  final VoidCallback onRetry;
  const _ResultView({
    required this.result, required this.imageFile,
    required this.onAccept, required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final confidenceColor = result.confidence >= 0.75
        ? AppColors.urgencyLow
        : result.confidence >= 0.45
            ? AppColors.urgencyMedium
            : AppColors.urgencyHigh;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Success banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.urgencyLow.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.urgencyLow.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.auto_awesome,
              color: AppColors.urgencyLow, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(result.explanation,
              style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary))),
            // Confidence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: confidenceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: confidenceColor.withValues(alpha: 0.4))),
              child: Text(
                '${(result.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: confidenceColor)),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Extracted fields preview
        const Text('EXTRACTED DATA', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.bold,
          letterSpacing: 1, color: AppColors.textSecondary)),
        const SizedBox(height: 8),

        _FieldPreview(icon: Icons.category,     label: 'Type',     value: result.needType.toUpperCase()),
        _FieldPreview(icon: Icons.warning_amber, label: 'Urgency',  value: result.urgencyLevel.toUpperCase()),
        _FieldPreview(icon: Icons.people,        label: 'People',   value: result.peopleAffected > 0 ? '${result.peopleAffected}' : 'Not detected'),
        _FieldPreview(icon: Icons.location_on,   label: 'Location', value: result.address.isNotEmpty ? result.address : 'Not detected'),
        _FieldPreview(icon: Icons.description,   label: 'Description',
          value: result.description.length > 60
              ? '${result.description.substring(0, 60)}…'
              : result.description),

        const SizedBox(height: 16),

        // Raw text accordion
        if (result.rawText.isNotEmpty)
          _RawTextAccordion(text: result.rawText),

        const SizedBox(height: 16),

        // Action buttons
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Scan Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Use This Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _FieldPreview extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _FieldPreview({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text('$label:', style: const TextStyle(
            fontSize: 12, color: AppColors.textSecondary))),
        Expanded(
          child: Text(value, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary))),
      ]),
    );
  }
}

class _RawTextAccordion extends StatefulWidget {
  final String text;
  const _RawTextAccordion({required this.text});
  @override
  State<_RawTextAccordion> createState() => _RawTextAccordionState();
}

class _RawTextAccordionState extends State<_RawTextAccordion> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.text_snippet, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            const Text('Raw OCR text', style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            Icon(_open ? Icons.expand_less : Icons.expand_more,
              size: 16, color: AppColors.textSecondary),
          ]),
          if (_open) ...[
            const SizedBox(height: 8),
            Text(widget.text, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary,
              fontFamily: 'monospace')),
          ]
        ]),
      ),
    );
  }
}

// ── Error view ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(children: [
        const Icon(Icons.error_outline,
          size: 48, color: AppColors.urgencyHigh),
        const SizedBox(height: 12),
        const Text('Scan Failed', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold,
          color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(message,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ]),
    );
  }
}
