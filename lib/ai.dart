// ai.dart
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';

class AiService {
  static const _modelName = 'gemini-2.5-flash';

  final GenerativeModel _model;

  AiService()
      : _model = FirebaseAI.googleAI().generativeModel(
    model: _modelName,
  );

  /// Sends a prompt and parses valid JSON feedback.
  /// Accepts optional imageDescription — use this when the firestore doc stores
  /// the label/description of the image.
  Future<Map<String, dynamic>> getFeedback({
    required String question,
    required List<String> options,
    required String correctAnswer,
    required String userAnswer,
    String? imageDescription,
    bool forceHindi = false,
  }) async {
    // language detection: check question OR imageDescription for Devanagari
    final combinedForLangCheck = '${question ?? ''} ${imageDescription ?? ''}';
    final isHindi = forceHindi ||
        RegExp(r'[\u0900-\u097F]').hasMatch(combinedForLangCheck);

    final languageInstruction = isHindi
        ? 'यदि प्रश्न या चित्र विवरण हिंदी में है, तो उत्तर हिंदी में दें; अन्यथा अंग्रेजी में उत्तर दें।'
        : 'If the question or image description is in Hindi, respond in Hindi; otherwise respond in English.';

    final safeImageDesc = (imageDescription == null || imageDescription.trim().isEmpty)
        ? '<none provided>'
        : imageDescription.trim();

    // Provide a clear JSON-only contract and instruct the model to NOT HALLUCINATE.
    final prompt = Content.text('''
You are given ONLY these facts. Use them — do NOT invent or hallucinate facts.

Question text:
${question.trim()}

Image description (from database; MAY be empty):
$safeImageDesc

Options:
${options.map((o) => '- ${o.trim()}').join('\n')}

Correct answer (one of the options exactly as above): $correctAnswer
User selected (one of the options exactly as above): $userAnswer

$languageInstruction

Task:
1) Guess why the user might have made this mistake (a short sentence).
2) Explain why the correct answer is right using ONLY the supplied facts (question text and image description). If the image description clearly says the object, base the explanation on that. 
3) If you cannot determine the reason from these facts, put 'UNKNOWN' as the value for that field — do NOT invent reasons.

Return **only** valid JSON with exactly two string fields: "mistake" and "explanation".
Example:
{"mistake": "User confused 'A' with 'B' because ...", "explanation": "The correct answer is X because ..."}

No extra text, no markdown, no backticks, no lists. JSON ONLY.
''');

    // 2. Make request to the model
    final response = await _model.generateContent([prompt]);
    final rawText = response.text ?? '';

    // helpful for debugging in logs (remove or gate this in production)
    // ignore: avoid_print
    print('AI raw response: >>>\n$rawText\n<<< end raw');

    if (rawText.trim().isEmpty) {
      throw Exception('No text returned from AI.');
    }

    final cleaned = _extractJson(rawText);

    // 3. Parse the cleaned JSON with several fallbacks
    try {
      final Map<String, dynamic> parsed = jsonDecode(cleaned);
      if (parsed.containsKey('mistake') && parsed.containsKey('explanation')) {
        // ensure both are strings (coerce)
        return {
          'mistake': parsed['mistake']?.toString() ?? 'UNKNOWN',
          'explanation': parsed['explanation']?.toString() ?? 'UNKNOWN',
        };
      } else {
        throw Exception('JSON missing required keys.');
      }
    } catch (e) {
      // final fallback: try to normalize single quotes -> double quotes (cautious)
      final alt = _tryFixSingleQuotes(cleaned);
      try {
        final Map<String, dynamic> parsed = jsonDecode(alt);
        if (parsed.containsKey('mistake') && parsed.containsKey('explanation')) {
          return {
            'mistake': parsed['mistake']?.toString() ?? 'UNKNOWN',
            'explanation': parsed['explanation']?.toString() ?? 'UNKNOWN',
          };
        } else {
          throw Exception('JSON missing required keys after alt parse.');
        }
      } catch (e2) {
        throw Exception(
          'Failed to parse AI JSON: $e\n\nTried alt parse: $e2\n\nOriginal Response:\n$rawText\n\nCleaned Text:\n$cleaned',
        );
      }
    }
  }

  /// Removes wrapping code fences and returns the first JSON object found.
  String _extractJson(String input) {
    var cleaned = input.replaceAll(RegExp(r'```+[\w]*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r"'''+[\w]*", multiLine: true), '');
    cleaned = cleaned.trim();

    // find the first {...} block
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (match != null) {
      return match.group(0)!.trim();
    }

    // fallback: return whole cleaned string
    return cleaned;
  }

  /// Very conservative single-quote -> double-quote fixer for JSON-like strings.
  String _tryFixSingleQuotes(String s) {
    // Replace ': ' with ": " and keys in single quotes -> double quotes
    // CAVEAT: only a last-resort tool — keep conservative.
    var out = s.replaceAll(RegExp(r"(?<=\{|,)\s*'([^']+)'\s*:"), r'"\1":');
    out = out.replaceAll(RegExp(r":\s*'([^']*)'(?=\s*(,|\}))"), r': "\1"');
    return out;
  }
}