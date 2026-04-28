import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// OCRResult — structured data extracted from an image by Gemini Vision
class OCRResult {
  final String description;
  final String needType;       // food / medical / shelter / water / clothing
  final String urgencyLevel;   // high / medium / low
  final int    peopleAffected;
  final String address;
  final String rawText;        // full OCR text for audit trail
  final double confidence;     // 0.0 – 1.0, how confident the parse was
  final String explanation;    // human-readable summary for the "AI extracted" banner

  const OCRResult({
    required this.description,
    required this.needType,
    required this.urgencyLevel,
    required this.peopleAffected,
    required this.address,
    required this.rawText,
    required this.confidence,
    required this.explanation,
  });
}

class OCRService {
  // ─── REPLACE with your actual Gemini API key ────────────────────────────
  // Get one free at https://aistudio.google.com/app/apikey
  static const String _apiKey = 'AIzaSyCFTTgsbFlcplHj_FwppFkFE0X7ReBS4lU';
  static const String _endpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/'
    'gemini-2.5-flash:generateContent?key=$_apiKey';

  /// Analyse [imageFile] and return structured OCR result.
  /// Falls back to smart mock when API key is not set (for demo/testing).
  static Future<OCRResult> extractFromImage(File imageFile) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY') {
      // Demo mode — return realistic mock so the app works without a key
      await Future.delayed(const Duration(milliseconds: 1800));
      return _mockResult();
    }

    try {
      final bytes  = await imageFile.readAsBytes();
      final base64 = base64Encode(bytes);
      final ext    = imageFile.path.split('.').last.toLowerCase();
      final mime   = ext == 'png' ? 'image/png' : 'image/jpeg';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {'mime_type': mime, 'data': base64}
              },
              {
                'text': _buildPrompt(),
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 512,
        }
      });

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
      }

      final json    = jsonDecode(response.body);
      final text    = json['candidates'][0]['content']['parts'][0]['text'] as String;
      return _parseGeminiResponse(text);

    } catch (e) {
      // On error, return partial result flagging the issue
      return OCRResult(
        description:    'Could not extract details — please fill manually.',
        needType:       'food',
        urgencyLevel:   'medium',
        peopleAffected: 0,
        address:        '',
        rawText:        e.toString(),
        confidence:     0.0,
        explanation:    'OCR failed: ${e.toString().substring(0, 80)}',
      );
    }
  }

  // ── Prompt ──────────────────────────────────────────────────────────────
  static String _buildPrompt() => '''
You are a disaster relief data extractor. Analyse this image and extract relief need information.

The image may show: a handwritten report, a printed notice, a WhatsApp screenshot, a photograph of a disaster scene, or a government notice.

Return ONLY a valid JSON object with exactly these fields:
{
  "description": "<1-2 sentence description of the need>",
  "needType": "<one of: food, medical, shelter, water, clothing>",
  "urgencyLevel": "<one of: high, medium, low>",
  "peopleAffected": <integer, estimate if not stated>,
  "address": "<location string or empty string>",
  "rawText": "<all text visible in the image>",
  "confidence": <float 0.0-1.0>,
  "explanation": "<one sentence: what you found and how confident>"
}

Rules:
- needType MUST be one of: food, medical, shelter, water, clothing
- urgencyLevel MUST be one of: high, medium, low
- peopleAffected must be a positive integer (estimate from context if unclear)
- If no location visible, use empty string for address
- confidence: 0.9+ for clear printed text, 0.6-0.8 for handwritten, 0.3-0.5 for scene photos
- Return ONLY the JSON — no markdown, no explanation outside the JSON
''';

  // ── Parser ───────────────────────────────────────────────────────────────
  static OCRResult _parseGeminiResponse(String text) {
    // Strip possible markdown fences
    var clean = text.trim();
    if (clean.startsWith('```')) {
      clean = clean.replaceAll(RegExp(r'```json?\n?'), '').replaceAll('```', '').trim();
    }

    final Map<String, dynamic> data = jsonDecode(clean);

    // Sanitise needType
    const validTypes = ['food', 'medical', 'shelter', 'water', 'clothing'];
    final rawType = (data['needType'] as String? ?? 'food').toLowerCase();
    final needType = validTypes.contains(rawType) ? rawType : 'food';

    // Sanitise urgencyLevel
    const validUrgency = ['high', 'medium', 'low'];
    final rawUrgency = (data['urgencyLevel'] as String? ?? 'medium').toLowerCase();
    final urgencyLevel = validUrgency.contains(rawUrgency) ? rawUrgency : 'medium';

    // Sanitise peopleAffected
    int people = 0;
    final rawPeople = data['peopleAffected'];
    if (rawPeople is int) {
      people = rawPeople;
    } else if (rawPeople is double) {
      people = rawPeople.toInt();
    } else if (rawPeople is String) {
      people = int.tryParse(rawPeople) ?? 0;
    }

    return OCRResult(
      description:    (data['description']    as String? ?? '').trim(),
      needType:       needType,
      urgencyLevel:   urgencyLevel,
      peopleAffected: people.clamp(0, 99999),
      address:        (data['address']        as String? ?? '').trim(),
      rawText:        (data['rawText']        as String? ?? '').trim(),
      confidence:     ((data['confidence']    as num?)   ?? 0.5).toDouble().clamp(0.0, 1.0),
      explanation:    (data['explanation']    as String? ?? '').trim(),
    );
  }

  // ── Demo mock (no API key) ────────────────────────────────────────────────
  static OCRResult _mockResult() => const OCRResult(
    description:    '150 families displaced by flooding need immediate food and clean water supply at the relief camp.',
    needType:       'food',
    urgencyLevel:   'high',
    peopleAffected: 150,
    address:        'Kolhapur Relief Camp, Maharashtra',
    rawText:        '[DEMO MODE — No Gemini API key set]\n'
                    'Relief Notice: 150 families affected.\n'
                    'Location: Kolhapur Relief Camp\n'
                    'Needs: Food, Water — URGENT',
    confidence:     0.92,
    explanation:    'Demo result — set your Gemini API key in ocr_service.dart to use real OCR.',
  );
}
