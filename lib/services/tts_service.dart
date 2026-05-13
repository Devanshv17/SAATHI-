import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  late FlutterTts _tts;
  bool _isSpeaking = false;

  TtsService._internal() {
    _tts = FlutterTts();
    _init();
  }

  void _init() async {
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.35);      // higher pitch — warm, teacher-like
    await _tts.setSpeechRate(0.37); // slightly slow for kids

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
  }

  // No-op — flutter_tts is on-device/instant, no pre-fetching needed.
  void prewarm(String text, {String? language}) {}

  Future<void> speak(String text, {String? language}) async {
    if (text.trim().isEmpty) return;
    if (_isSpeaking) await stop();

    if (language == 'hi-IN') {
      await _tts.setLanguage('hi-IN');
      await _tts.setSpeechRate(0.40);
      await _tts.setPitch(1.3);
    } else {
      await _tts.setLanguage('en-IN'); // Indian English accent
      await _tts.setSpeechRate(0.37);
      await _tts.setPitch(1.35);
    }

    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }
}
