import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  TtsService._internal() {
    _flutterTts = FlutterTts();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    // We can leave this default here, but we will override it in the speak() method
    await _flutterTts.setSpeechRate(0.6);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });
  }

  // --- UPDATED SPEAK METHOD ---
  Future<void> speak(String text, {String? language}) async {
    if (text.isEmpty) return;

    if (_isSpeaking) {
      await stop();
    }

    if (language != null) {
      await _flutterTts.setLanguage(language);

      // Boost the speed if it is Hindi!
      if (language == 'hi-IN') {
        await _flutterTts.setSpeechRate(
            0.65); // <-- Increase this number if it's still too slow (max is 1.0)
      } else {
        await _flutterTts.setSpeechRate(0.5); // <-- Standard speed for English
      }
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
