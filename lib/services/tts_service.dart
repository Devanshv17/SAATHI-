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
    await _flutterTts.setSpeechRate(0.5);
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

  Future<void> speak(String text, {String? language}) async {
    if (text.isEmpty) return;
    
    if (_isSpeaking) {
      await stop();
    }

    if (language != null) {
       await _flutterTts.setLanguage(language);
    } else {
       // Default fallback if strictly needed, but usually we pass language
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
