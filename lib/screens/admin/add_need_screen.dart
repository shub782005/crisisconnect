import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/needs_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/priority_service.dart';
import '../../services/ocr_service.dart';
import '../../widgets/ocr_scan_sheet.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/urgency_badge.dart';


class AddNeedScreen extends StatefulWidget {
  const AddNeedScreen({super.key});
  @override
  State<AddNeedScreen> createState() => _AddNeedScreenState();
}

class _AddNeedScreenState extends State<AddNeedScreen>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _descCtrl  = TextEditingController();
  final _peopleCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _selectedType    = 'food';
  String _selectedUrgency = 'medium';
  double _previewScore    = 0.5;
  bool   _ocrtAutoFilled  = false;   // shows the "AI filled" banner

  // Highlight controllers for the auto-fill animation
  late AnimationController _fillAnimCtrl;
  late Animation<Color?>    _fillAnim;

  final List<Map<String, dynamic>> _needTypes = [
    {'value': 'food',     'label': 'Food',     'icon': Icons.restaurant},
    {'value': 'medical',  'label': 'Medical',  'icon': Icons.medical_services},
    {'value': 'shelter',  'label': 'Shelter',  'icon': Icons.home},
    {'value': 'water',    'label': 'Water',    'icon': Icons.water_drop},
    {'value': 'clothing', 'label': 'Clothing', 'icon': Icons.checkroom},
  ];

  @override
  void initState() {
    super.initState();
    _fillAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _fillAnim = ColorTween(
      begin: AppColors.primary.withValues(alpha: 0.18),
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _fillAnimCtrl, curve: Curves.easeOut));
    _updatePreviewScore();
  }

  @override
  void dispose() {
    _fillAnimCtrl.dispose();
    _descCtrl.dispose();
    _peopleCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _updatePreviewScore() {
    final people = int.tryParse(_peopleCtrl.text) ?? 10;
    setState(() {
      _previewScore = PriorityService.calculatePriorityScore(
        needType:       _selectedType,
        peopleAffected: people,
        urgencyLevel:   _selectedUrgency,
        hoursOld:       0,
      );
    });
  }

  // ── OCR auto-fill ──────────────────────────────────────────────────────────
  void _onOCRResult(OCRResult result) {
    // Fill all fields
    _descCtrl.text   = result.description;
    _addressCtrl.text = result.address;
    if (result.peopleAffected > 0) {
      _peopleCtrl.text = result.peopleAffected.toString();
    }

    setState(() {
      _selectedType    = result.needType;
      _selectedUrgency = result.urgencyLevel;
      _ocrtAutoFilled  = true;
    });

    _updatePreviewScore();

    // Flash highlight animation on all fields
    _fillAnimCtrl.forward(from: 0);

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'AI filled ${_filledCount(result)} fields — confidence ${(result.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: AppColors.urgencyLow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  int _filledCount(OCRResult r) {
    int c = 2; // type + urgency always
    if (r.description.isNotEmpty) c++;
    if (r.peopleAffected > 0)     c++;
    if (r.address.isNotEmpty)     c++;
    return c;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth  = context.read<AuthProvider>();
    final needs = context.read<NeedsProvider>();
    final success = await needs.addNeed(
      type:           _selectedType,
      description:    _descCtrl.text.trim(),
      peopleAffected: int.parse(_peopleCtrl.text.trim()),
      urgencyLevel:   _selectedUrgency,
      address:        _addressCtrl.text.trim(),
      lat: 16.7050,
      lng: 74.2433,
      reportedBy: auth.currentUser?.id ?? 'admin',
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Need reported and AI-scored!'),
        backgroundColor: AppColors.urgencyLow,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needs = context.watch<NeedsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report Community Need'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // OCR button in app bar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => showOCRScanSheet(
                context, onSuccess: _onOCRResult),
              icon: const Icon(Icons.document_scanner, size: 18,
                color: Colors.white),
              label: const Text('Scan Doc',
                style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── OCR banner ───────────────────────────────────────────────
              _OCRBanner(
                filled: _ocrtAutoFilled,
                onScan: () => showOCRScanSheet(
                  context, onSuccess: _onOCRResult),
              ),

              const SizedBox(height: 20),

              // ── AI auto-filled indicator ─────────────────────────────────
              if (_ocrtAutoFilled)
                AnimatedBuilder(
                  animation: _fillAnim,
                  builder: (_, __) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _fillAnim.value ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25))),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome,
                        size: 14, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('Fields auto-filled by AI — review and edit if needed',
                        style: TextStyle(
                          fontSize: 12, color: AppColors.primary)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _ocrtAutoFilled = false),
                        child: const Icon(Icons.close,
                          size: 14, color: AppColors.textSecondary)),
                    ]),
                  ),
                ),

              // ── Need type ────────────────────────────────────────────────
              const _SectionLabel(label: 'Need Type'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _needTypes.map((t) {
                    final selected = _selectedType == t['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedType = t['value']);
                          _updatePreviewScore();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                ? AppColors.primary
                                : Colors.grey.shade300),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(t['icon'] as IconData,
                              size: 16,
                              color: selected ? Colors.white : AppColors.primary),
                            const SizedBox(width: 6),
                            Text(t['label'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary)),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // ── Description ──────────────────────────────────────────────
              const _SectionLabel(label: 'Description'),
              AnimatedBuilder(
                animation: _fillAnim,
                builder: (_, child) => Container(
                  decoration: BoxDecoration(
                    color: _fillAnim.value,
                    borderRadius: BorderRadius.circular(8)),
                  child: child,
                ),
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe the situation...',
                    border: OutlineInputBorder(),
                    filled: true, fillColor: Colors.white,
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter description' : null,
                ),
              ),

              const SizedBox(height: 16),

              // ── People affected ──────────────────────────────────────────
              const _SectionLabel(label: 'People Affected'),
              AnimatedBuilder(
                animation: _fillAnim,
                builder: (_, child) => Container(
                  decoration: BoxDecoration(
                    color: _fillAnim.value,
                    borderRadius: BorderRadius.circular(8)),
                  child: child,
                ),
                child: TextFormField(
                  controller: _peopleCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updatePreviewScore(),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 150',
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                    filled: true, fillColor: Colors.white,
                  ),
                  validator: (v) => (int.tryParse(v ?? '') == null)
                    ? 'Enter a valid number' : null,
                ),
              ),

              const SizedBox(height: 16),

              // ── Urgency ──────────────────────────────────────────────────
              const _SectionLabel(label: 'Urgency Level'),
              Row(children: ['high', 'medium', 'low'].map((u) {
                final selected = _selectedUrgency == u;
                return Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedUrgency = u);
                      _updatePreviewScore();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                          ? AppColors.urgencyColor(u).withValues(alpha: 0.15)
                          : Colors.white,
                        border: Border.all(
                          color: selected
                            ? AppColors.urgencyColor(u)
                            : Colors.grey.shade300,
                          width: selected ? 2 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: UrgencyBadge(level: u)),
                    ),
                  ),
                ));
              }).toList()),

              const SizedBox(height: 16),

              // ── Address ──────────────────────────────────────────────────
              const _SectionLabel(label: 'Location / Address'),
              AnimatedBuilder(
                animation: _fillAnim,
                builder: (_, child) => Container(
                  decoration: BoxDecoration(
                    color: _fillAnim.value,
                    borderRadius: BorderRadius.circular(8)),
                  child: child,
                ),
                child: TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Kolhapur Relief Camp, Maharashtra',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                    filled: true, fillColor: Colors.white,
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter location' : null,
                ),
              ),

              const SizedBox(height: 24),

              // ── AI Score Preview ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Priority Score',
                        style: TextStyle(fontWeight: FontWeight.w600,
                          color: AppColors.primary, fontSize: 13)),
                      Text(PriorityService.explainScore(
                        needType:       _selectedType,
                        peopleAffected: int.tryParse(_peopleCtrl.text) ?? 10,
                        urgencyLevel:   _selectedUrgency,
                        hoursOld:       0,
                        score:          _previewScore,
                      ),
                        style: const TextStyle(fontSize: 12,
                          color: AppColors.textSecondary)),
                    ],
                  )),
                  Text(
                    '${(_previewScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold,
                      color: AppColors.urgencyColor(
                        PriorityService.scoreToLabel(_previewScore)))),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Submit ───────────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: needs.isLoading ? null : _submit,
                  icon: needs.isLoading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                  label: const Text('Report Need',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  OCR BANNER  — top of the form
// ═══════════════════════════════════════════════════════════════════════════════
class _OCRBanner extends StatelessWidget {
  final bool filled;
  final VoidCallback onScan;
  const _OCRBanner({required this.filled, required this.onScan});

  @override
  Widget build(BuildContext context) {
    if (filled) {
      // Compact "re-scan" strip after data is already filled
      return GestureDetector(
        onTap: onScan,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.3))),
          child: const Row(children: [
            Icon(Icons.document_scanner,
              color: AppColors.secondary, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text('Form filled by AI scan · Tap to re-scan',
                style: TextStyle(
                  fontSize: 13, color: AppColors.secondary,
                  fontWeight: FontWeight.w500))),
            Icon(Icons.refresh,
              color: AppColors.secondary, size: 16),
          ]),
        ),
      );
    }

    // Full banner — encourages scanning
    return GestureDetector(
      onTap: onScan,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.document_scanner,
              color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📸 Scan Document to Auto-Fill',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
                SizedBox(height: 3),
                Text('Point at any notice, report, or handwritten note.\nGemini AI extracts all fields automatically.',
                  style: TextStyle(
                    color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
            color: Colors.white70, size: 14),
        ]),
      ),
    );
  }
}

// ── Reusable section label ────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: const TextStyle(
      fontWeight: FontWeight.w600, fontSize: 14,
      color: AppColors.textPrimary)),
  );
}
