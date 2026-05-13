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
    final combinedForLangCheck = '$question ${imageDescription ?? ''}';
    final isHindi = forceHindi ||
        RegExp(r'[\u0900-\u097F]').hasMatch(combinedForLangCheck);

    final safeImageDesc = (imageDescription == null || imageDescription.trim().isEmpty)
        ? (isHindi ? '<कोई विवरण नहीं>' : '<none provided>')
        : imageDescription.trim();

    final prompt = Content.text(isHindi ? '''
सख्त भाषा नियम: सम्पूर्ण उत्तर केवल हिंदी (देवनागरी लिपि) में दें। एक भी अंग्रेजी शब्द नहीं। "mistake" और "explanation" दोनों फ़ील्ड पूरी तरह हिंदी में होने चाहिए।

आप बच्चों के लिए एक स्मार्ट शिक्षक हैं। सीधे बात करें — प्रश्न को वापस मत दोहराएं और कभी यह मत लिखें "सही उत्तर X है क्योंकि सही उत्तर X है।"

ऐप की जानकारी (बहुत ज़रूरी): ऐप में सही उत्तर हमेशा बाईं तरफ हरी बॉर्डर के साथ दिखता है। गलत उत्तर दाईं तरफ लाल बॉर्डर के साथ होता है। अपने explanation में इसका उल्लेख करें — जैसे "बाईं तरफ का चित्र एक बंदर दिखाता है" या "बाईं तरफ हरी बॉर्डर में अंक 8 है।"

तथ्य (केवल इन्हीं का उपयोग करें — कुछ भी मत बनाएं):
- प्रश्न: ${question.trim()}
- चित्र विवरण: $safeImageDesc
  ${safeImageDesc != '<कोई विवरण नहीं>' ? '(अगर यह एक अंक है जैसे "3", तो इसका मतलब है चित्र में 3 वस्तुएं हैं।)' : ''}
- सही उत्तर: $correctAnswer
- बच्चे ने चुना: $userAnswer

आपका काम — दो फ़ील्ड लिखें:
1. "mistake": एक छोटा वाक्य जो बताए कि बच्चा क्यों भ्रमित हुआ। सटीक बताएं (जैसे "'ब' और 'व' एक जैसे लगते हैं इसलिए भ्रम हुआ" — न कि बस "गलती हो गई")।
2. "explanation": एक-दो वाक्य जो बताएं कि सही उत्तर क्यों सही है। बाईं तरफ के चित्र/अंक का उल्लेख करें (जैसे "बाईं तरफ हरी बॉर्डर वाले चित्र में एक बिल्ली है, इसलिए उत्तर 'बिल्ली' है।")। केवल दिए गए तथ्यों का उपयोग करें। अगर कारण नहीं पता तो "UNKNOWN" लिखें।

नियम:
- "सही उत्तर X है क्योंकि सही उत्तर X है" — यह कभी मत लिखें।
- प्रश्न को शब्द-दर-शब्द मत दोहराएं।
- सरल, सीधी, और बच्चे के अनुकूल भाषा में लिखें।
- केवल JSON — कोई markdown, backtick, या अतिरिक्त text नहीं।

{"mistake": "...", "explanation": "..."}
''' : '''
STRICT LANGUAGE RULE: Respond entirely in English. Do not use Hindi.

You are a concise, smart educational tutor for children. Be specific — never repeat the question back or say "The correct answer is X because the correct answer is X." Get straight to the point.

UI FACT (very important): In the app, the CORRECT answer card is always displayed on the LEFT with a GREEN border. The student's wrong answer is on the RIGHT with a RED border. Reference this in your explanation — e.g. "The card on the left shows a monkey" or "The number on the left side is 8."

FACTS (use ONLY these — do NOT invent anything):
- Question: ${question.trim()}
- Image description: $safeImageDesc
  ${safeImageDesc != '<none provided>' ? '(If this is a number like "3", it means there are 3 objects in the image.)' : ''}
- Correct answer: $correctAnswer
- Student chose: $userAnswer

YOUR TASK — write TWO fields:
1. "mistake": One short sentence explaining the likely confusion. Be specific (e.g. "You may have mixed up 'b' and 'd' since they look similar" not "You made a mistake").
2. "explanation": One or two sentences explaining WHY the correct answer is right. Mention the left-side visual (e.g. "The image on the left with the green border shows a cat, so the answer is 'Cat'."). Use ONLY the supplied facts. If you truly cannot determine the reason, write "UNKNOWN".

RULES:
- Never start with "The correct answer is X because the correct answer is X" — that is redundant.
- Never repeat the question text verbatim.
- Be direct, specific, and child-friendly.
- JSON ONLY — no markdown, no backticks, no extra text.

{"mistake": "...", "explanation": "..."}
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

  /// Follow-up chat: sends a user question with the full answer context pre-loaded.
  Future<String> sendFollowUp({
    required String question,
    required String correctAnswer,
    required String userAnswer,
    required String explanation,
    required String userMessage,
    String? imageDescription,
    bool forceHindi = false,
  }) async {
    final isHindi = forceHindi ||
        RegExp(r'[ऀ-ॿ]').hasMatch('$question $userMessage');

    final safeImageDesc = (imageDescription == null || imageDescription.trim().isEmpty)
        ? '<none>'
        : imageDescription.trim();

    final prompt = Content.text(isHindi ? '''
सख्त भाषा नियम: केवल हिंदी (देवनागरी) में उत्तर दें। कोई अंग्रेजी नहीं।

आप एक दोस्ताना शिक्षक हैं जो बच्चे की मदद कर रहे हैं। सीधे और स्पष्ट जवाब दें — दोहराएं नहीं।

ऐप की जानकारी: सही उत्तर हमेशा बाईं तरफ हरी बॉर्डर के साथ दिखता है। गलत उत्तर दाईं तरफ लाल बॉर्डर के साथ। आप इसका उल्लेख कर सकते हैं (जैसे "बाईं तरफ वाले कार्ड में 8 सेब हैं")।

--- संदर्भ ---
प्रश्न: ${question.trim()}
चित्र विवरण: $safeImageDesc
सही उत्तर: $correctAnswer
बच्चे ने चुना: $userAnswer
पहले दी गई व्याख्या: ${explanation.trim()}
--- संदर्भ समाप्त ---

बच्चे का सवाल: ${userMessage.trim()}

2-3 वाक्यों में जवाब दें। सटीक, सरल, और हौसला बढ़ाने वाला। केवल plain text — कोई JSON नहीं।
''' : '''
STRICT LANGUAGE RULE: Respond entirely in English. Do not use Hindi.

You are a friendly educational tutor helping a child understand why they got a quiz question wrong. Answer their follow-up question clearly and specifically — never be vague or repeat yourself.

UI FACT: In the app, the CORRECT answer is always on the LEFT side with a GREEN border. The student's wrong answer is on the RIGHT with a RED border. You can reference this (e.g. "Look at the card on the left — it shows 8 apples").

--- CONTEXT ---
Quiz question: ${question.trim()}
Image description: $safeImageDesc
Correct answer: $correctAnswer
Student chose: $userAnswer
Explanation already shown: ${explanation.trim()}
--- END CONTEXT ---

Student's follow-up question: ${userMessage.trim()}

Answer in 2-3 sentences. Be specific, direct, and encouraging. No JSON — plain text only.
''');

    final response = await _model.generateContent([prompt]);
    final text = response.text ?? '';
    if (text.trim().isEmpty) throw Exception('No response from AI.');
    return text.trim();
  }

  /// Very conservative single-quote -> double-quote fixer for JSON-like strings.
  String _tryFixSingleQuotes(String s) {
    // Replace keys and string values enclosed in single quotes to double quotes
    // CAVEAT: only a last-resort tool — keep conservative.
    var out = s.replaceAll(RegExp(r"(?<=\{|,)\s*'([^']+)'\s*:"), r'"\1":');
    out = out.replaceAll(RegExp(r":\s*'([^']*)'(?=\s*(,|\}))"), r': "\1"');
    return out;
  }
}