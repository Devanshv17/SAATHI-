// lib/video_lesson.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

/// A zero‑cost TTS service leveraging Google Translate’s TTS endpoint.
/// ⚠️ This is an unofficial endpoint and may change, but it’s
/// been stable for years in many community tools.
class GoogleTranslateTtsService {
  /// Compute a cache path unique to [text]+[locale].
  Future<String> _getCachePath(String text, String locale) async {
    final dir = await getApplicationDocumentsDirectory();
    final safe = '${locale}_${text.hashCode}';
    return '${dir.path}/$safe.mp3';
  }

  Future<void> speak(String text) async {
    // Detect Hindi vs. English
    final isHindi = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    final lang = isHindi ? 'hi' : 'en';

    final path = await _getCachePath(text, lang);
    final file = File(path);

    if (!await file.exists()) {
      // Build the Google Translate TTS URL
      final uri = Uri.parse(
          'https://translate.google.com/translate_tts'
              '?ie=UTF-8'
              '&q=${Uri.encodeComponent(text)}'
              '&tl=$lang'
              '&client=gtx'
      );

      // Must include a realistic User-Agent
      final res = await http.get(uri, headers: {
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/104.0.0.0 Safari/537.36',
        'Accept': 'audio/mpeg',
      });

      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception(
          'Translate TTS failed (${res.statusCode}): ${res.body}',
        );
      }

      // Cache the MP3 bytes
      await file.writeAsBytes(res.bodyBytes, flush: true);
    }

    // Play the cached file
    final player = AudioPlayer();
    await player.play(DeviceFileSource(path));
  }
}

/// “Video lesson” widget exactly as before, now using GoogleTranslateTtsService.
class VideoLesson extends StatefulWidget {
  final String script;
  const VideoLesson({Key? key, required this.script}) : super(key: key);

  @override
  _VideoLessonState createState() => _VideoLessonState();
}

class _VideoLessonState extends State<VideoLesson> {
  late final GoogleTranslateTtsService _ttsService;
  late final List<String> _slides;
  int _currentSlide = 0;
  Completer<void>? _textAnimationCompleter;

  @override
  void initState() {
    super.initState();

    _ttsService = GoogleTranslateTtsService();

    _slides = widget.script
        .split(RegExp(r'(?<=[.?!])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playSlides();
    });
  }

  Future<void> _playSlides() async {
    while (_currentSlide < _slides.length) {
      final text = _slides[_currentSlide];

      // Animate text
      _textAnimationCompleter = Completer<void>();
      setState(() {});

      // Speak via Google Translate TTS
      try {
        await _ttsService.speak(text);
      } catch (e) {
        debugPrint('TTS error: $e');
      }

      // Wait for animation to finish
      await _textAnimationCompleter?.future;

      // Short pause, next slide
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _currentSlide++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _currentSlide >= _slides.length;
    final displayText = done ? '— End of lesson —' : _slides[_currentSlide];

    return Scaffold(
      appBar: AppBar(title: const Text('Video Lesson')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            child: AnimatedTextKit(
              key: ValueKey<int>(_currentSlide),
              isRepeatingAnimation: false,
              totalRepeatCount: 1,
              animatedTexts: [
                TypewriterAnimatedText(
                  displayText,
                  speed: const Duration(milliseconds: 50),
                  cursor: '|',
                ),
              ],
              onFinished: () {
                _textAnimationCompleter?.complete();
              },
            ),
          ),
        ),
      ),
    );
  }
}
