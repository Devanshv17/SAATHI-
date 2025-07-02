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
  Future<Map<String, dynamic>> getFeedback({
    required String question,
    required List<String> options,
    required String correctAnswer,
    required String userAnswer,
  }) async {
    // Detect language: check for Devanagari characters (Hindi)
    final isHindi = RegExp(r'[\u0900-\u097F]').hasMatch(question);
    final languageInstruction = isHindi
        ? 'यदि प्रश्न हिंदी में है, तो उत्तर हिंदी में दें; अन्यथा अंग्रेजी में उत्तर दें।'
        : 'If the question is in Hindi, respond in Hindi; otherwise, respond in English.';

    // 1. Construct a clean, strict prompt
    final prompt = Content.text('''
This is the question:
$question

Options:
${options.map((o) => '- $o').join('\n')}

Correct answer: $correctAnswer  
User selected: $userAnswer

$languageInstruction

Please guess why the user might have made this mistake, then explain why the correct answer is right. if the question is in hindi then answer in hindi only

Respond with ONLY valid JSON using **exactly** two fields: "mistake" and "explanation".
Do NOT include markdown, backticks, or any formatting. Just raw JSON like:
{"mistake": "...", "explanation": "..."}
''');

    // 2. Make request to Gemini model
    final response = await _model.generateContent([prompt]);
    final rawText = response.text;

    if (rawText == null || rawText.trim().isEmpty) {
      throw Exception('No text returned from AI.');
    }

    final cleaned = _extractJson(rawText);

    // 3. Parse the cleaned JSON
    try {
      final Map<String, dynamic> parsed = jsonDecode(cleaned);
      if (parsed.containsKey('mistake') && parsed.containsKey('explanation')) {
        return parsed;
      } else {
        throw Exception(
          'JSON missing required keys.\nReturned: \$parsed',
        );
      }
    } catch (e) {
      throw Exception(
        'Failed to parse AI JSON: \$e\n\nOriginal Response:\n\$rawText\n\nCleaned Text:\n\$cleaned',
      );
    }
  }

  /// Removes wrapping ```json, '''json and extra formatting.
  String _extractJson(String input) {
    // Strip markdown/code block indicators like ```json, ```, '''json, '''
    final cleaned = input
        .replaceAll(RegExp(r'(```json|```)', multiLine: true), '')
        .trim();

    // If still malformed, try to extract first JSON-like section
    final match = RegExp(r'{[\s\S]*}').firstMatch(cleaned);
    return match?.group(0)?.trim() ?? cleaned;
  }
}
