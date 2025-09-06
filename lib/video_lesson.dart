// lib/video_lesson.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';

/// Google Translate TTS (unofficial endpoint) with simple file caching.
/// Note: this uses an unofficial endpoint — works for many community tools but may change.
class GoogleTranslateTtsService {
  Future<String> _getCachePath(String text, String locale) async {
    final dir = await getApplicationDocumentsDirectory();
    final safe = '${locale}_${text.hashCode}';
    return '${dir.path}/$safe.mp3';
  }

  /// Speaks text using Google Translate TTS, caching the MP3.
  /// `localeOverride` can be 'hi' or 'en' to force language.
  Future<void> speak(String text, {String? localeOverride}) async {
    if (text.trim().isEmpty) return;
    final guessedHindi = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    final isHindi = localeOverride == 'hi'
        ? true
        : (localeOverride == 'en' ? false : guessedHindi);
    final lang = localeOverride ?? (isHindi ? 'hi' : 'en');

    final path = await _getCachePath(text, lang);
    final file = File(path);

    if (!await file.exists()) {
      final uri = Uri.parse(
        'https://translate.google.com/translate_tts'
        '?ie=UTF-8'
        '&q=${Uri.encodeComponent(text)}'
        '&tl=$lang'
        '&client=gtx',
      );

      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/104.0.0.0 Safari/537.36',
        'Accept': 'audio/mpeg',
      });

      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception('Translate TTS failed (${res.statusCode})');
      }

      await file.writeAsBytes(res.bodyBytes, flush: true);
    }

    final player = AudioPlayer();
    // Play cached file; await to keep flow predictable.
    try {
      await player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('TTS playback error: $e');
    }
  }
}

/// VideoLesson widget
///
/// Usage (examples):
/// - VideoLesson(script: "AI text...")                                      // default fullscreen
/// - VideoLesson(fromPage: 'matching', question: q, correctOption: c, attemptedOption: a, script: s)
/// - VideoLesson(fromPage: 'letuscount', question: q, correctOption: c, attemptedOption: a, imageAssets: imgs, script: s)
/// - VideoLesson(fromPage: 'guesstheletter', question: q, correctOption: c, attemptedOption: a, imageUrl: url, script: s)
/// - VideoLesson(fromPage: 'compare', question: q, correctOption: c, attemptedOption: a, leftAssets: l, rightAssets: r, script: s)
/// - VideoLesson(fromPage: 'letustelltime', question: q, correctOption: c, attemptedOption: a, clockTime: dt, script: s)
class VideoLesson extends StatefulWidget {
  final String script;
  final String? fromPage;
  final String? question;
  final String? correctOption;
  final String? attemptedOption;
  final List<String>? imageAssets; // letuscount
  final List<String>? leftAssets; // compare
  final List<String>? rightAssets; // compare
  final String? imageUrl; // guesstheletter
  final DateTime? clockTime; // letustelltime
  final bool? isHindi;

  const VideoLesson({
    Key? key,
    required this.script,
    this.fromPage,
    this.question,
    this.correctOption,
    this.attemptedOption,
    this.imageAssets,
    this.leftAssets,
    this.rightAssets,
    this.imageUrl,
    this.clockTime,
    this.isHindi,
  }) : super(key: key);

  @override
  _VideoLessonState createState() => _VideoLessonState();
}

class _VideoLessonState extends State<VideoLesson> {
  late final GoogleTranslateTtsService _ttsService;
  late final List<String> _slides;
  int _currentSlide = 0;
  Completer<void>? _textAnimationCompleter;

  // Header fields for special modes
  String headerQuestion = '';
  String headerCorrect = '';
  String headerAttempted = '';
  List<String> headerImages = [];
  List<String> headerLeft = [];
  List<String> headerRight = [];
  String? headerImageUrl;
  DateTime? headerClockTime;

  @override
  void initState() {
    super.initState();
    _ttsService = GoogleTranslateTtsService();

    headerQuestion = widget.question?.trim() ?? '';
    headerCorrect = widget.correctOption?.trim() ?? '';
    headerAttempted = widget.attemptedOption?.trim() ?? '';
    headerImages = widget.imageAssets ?? [];
    headerLeft = widget.leftAssets ?? [];
    headerRight = widget.rightAssets ?? [];
    headerImageUrl = widget.imageUrl;
    headerClockTime = widget.clockTime;

    // Split script into sentence-like slides for the animated text area.
    _slides = widget.script
        .split(RegExp(r'(?<=[.?!])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    debugPrint(
        'VideoLesson init: fromPage=${widget.fromPage}, slides=${_slides.length}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _playSlides());
  }

  @override
  void dispose() {
    // nothing to dispose in service currently; but keep method for future cleanup
    super.dispose();
  }

  Future<void> _playSlides() async {
    while (_currentSlide < _slides.length) {
      final text = _slides[_currentSlide];

      // Prepare animation completer
      _textAnimationCompleter = Completer<void>();
      setState(() {}); // rebuild AnimatedTextKit (it uses ValueKey to restart)

      // Speak via TTS (catch errors but don't block)
      try {
        final langOverride = widget.isHindi == true ? 'hi' : null;
        await _ttsService.speak(text, localeOverride: langOverride);
      } catch (e) {
        debugPrint('TTS error: $e');
      }

      // Wait until the typewriter animation finishes
      await _textAnimationCompleter?.future;

      // Short pause then next slide
      await Future.delayed(const Duration(milliseconds: 700));
      setState(() => _currentSlide++);
    }
  }

  Widget _buildOptionCard({
    required String label,
    required String content,
    required Color borderColor,
    required bool showTick,
    bool isAttempt = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6.0),
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 6)
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: Text(
                        content,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showTick)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle, color: Colors.green, size: 28),
              ),
            if (!showTick && isAttempt)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.close, color: Colors.red, size: 28),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesWrap(List<String> assets) {
    if (assets.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: assets
          .map((a) => Image.asset(a,
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) =>
                  const SizedBox(width: 40, height: 40)))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _currentSlide >= _slides.length;
    final currentAnimatedText = done
        ? (widget.isHindi == true ? '— पाठ समाप्त —' : '— End of lesson —')
        : (_slides.isNotEmpty ? _slides[_currentSlide] : '');

    // -------------------- LETUSTELLTIME MODE --------------------
    if (widget.fromPage == 'letustelltime') {
      final labelCorrect = widget.isHindi == true ? 'सही' : 'Correct';
      final labelYour = widget.isHindi == true ? 'आपका उत्तर' : 'Your answer';
      final correctText = headerCorrect.isEmpty ? '-' : headerCorrect;
      final attemptedText = headerAttempted.isEmpty ? '-' : headerAttempted;
      final attemptedIsCorrect = headerCorrect.trim().isNotEmpty &&
          (headerCorrect.trim() == headerAttempted.trim());

      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isHindi == true ? 'AI विश्लेषण' : 'AI Explanation')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Question heading
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.12), blurRadius: 6)
                    ],
                  ),
                  child: Text(
                    headerQuestion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 12),

                // Analog clock
                if (headerClockTime != null)
                  Container(
                    width: 180,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                      boxShadow: const [
                        BoxShadow(
                            blurRadius: 4,
                            color: Colors.black12,
                            offset: Offset(2, 2))
                      ],
                    ),
                    child: ClipOval(
                      child: AnalogClock(
                          key: ValueKey(headerClockTime),
                          dateTime: headerClockTime!),
                    ),
                  ),

                const SizedBox(height: 12),

                // Option cards
                Row(
                  children: [
                    _buildOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildOptionCard(
                        label: labelYour,
                        content: attemptedText,
                        borderColor:
                            attemptedIsCorrect ? Colors.green : Colors.red,
                        showTick: attemptedIsCorrect,
                        isAttempt: true),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),

                // Animated writeup
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.10),
                              blurRadius: 6)
                        ]),
                    child: DefaultTextStyle(
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black87),
                      child: AnimatedTextKit(
                        key: ValueKey<int>(_currentSlide),
                        isRepeatingAnimation: false,
                        totalRepeatCount: 1,
                        animatedTexts: [
                          TypewriterAnimatedText(currentAnimatedText,
                              speed: const Duration(milliseconds: 40),
                              cursor: '|'),
                        ],
                        onFinished: () => _textAnimationCompleter?.complete(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // -------------------- COMPARE MODE --------------------
    if (widget.fromPage == 'compare') {
      final labelCorrect = widget.isHindi == true ? 'सही' : 'Correct';
      final labelYour = widget.isHindi == true ? 'आपका उत्तर' : 'Your answer';
      final correctText = headerCorrect.isEmpty ? '-' : headerCorrect;
      final attemptedText = headerAttempted.isEmpty ? '-' : headerAttempted;
      final attemptedIsCorrect = headerCorrect.trim().isNotEmpty &&
          (headerCorrect.trim() == headerAttempted.trim());

      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isHindi == true ? 'AI विश्लेषण' : 'AI Explanation')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Question heading
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.12), blurRadius: 6)
                      ]),
                  child: Text(headerQuestion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),

                // Left/Right image grids
                Row(
                  children: [
                    Expanded(
                        child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border:
                                    Border.all(color: Colors.black54, width: 2),
                                borderRadius: BorderRadius.circular(12)),
                            child: _buildImagesWrap(headerLeft))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border:
                                    Border.all(color: Colors.black54, width: 2),
                                borderRadius: BorderRadius.circular(12)),
                            child: _buildImagesWrap(headerRight))),
                  ],
                ),

                const SizedBox(height: 12),
                Text(
                    widget.isHindi == true
                        ? 'अ                          ब'
                        : 'A                          B',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Option cards
                Row(
                  children: [
                    _buildOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildOptionCard(
                        label: labelYour,
                        content: attemptedText,
                        borderColor:
                            attemptedIsCorrect ? Colors.green : Colors.red,
                        showTick: attemptedIsCorrect,
                        isAttempt: true),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                // Animated writeup
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.10),
                              blurRadius: 6)
                        ]),
                    child: DefaultTextStyle(
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black87),
                      child: AnimatedTextKit(
                        key: ValueKey<int>(_currentSlide),
                        isRepeatingAnimation: false,
                        totalRepeatCount: 1,
                        animatedTexts: [
                          TypewriterAnimatedText(currentAnimatedText,
                              speed: const Duration(milliseconds: 40),
                              cursor: '|'),
                        ],
                        onFinished: () => _textAnimationCompleter?.complete(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // -------------------- LETUSCOUNT MODE --------------------
    if (widget.fromPage == 'letuscount') {
      final labelCorrect = widget.isHindi == true ? 'सही' : 'Correct';
      final labelYour = widget.isHindi == true ? 'आपका उत्तर' : 'Your answer';
      final correctText = headerCorrect.isEmpty ? '-' : headerCorrect;
      final attemptedText = headerAttempted.isEmpty ? '-' : headerAttempted;
      final attemptedIsCorrect = headerCorrect.trim().isNotEmpty &&
          (headerCorrect.trim() == headerAttempted.trim());

      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isHindi == true ? 'AI विश्लेषण' : 'AI Explanation')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Question
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.12), blurRadius: 6)
                      ]),
                  child: Text(headerQuestion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),

                // Images grid (from assets)
                _buildImagesWrap(headerImages),
                const SizedBox(height: 12),

                // Options
                Row(
                  children: [
                    _buildOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildOptionCard(
                        label: labelYour,
                        content: attemptedText,
                        borderColor:
                            attemptedIsCorrect ? Colors.green : Colors.red,
                        showTick: attemptedIsCorrect,
                        isAttempt: true),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),

                // Animated writeup
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.10),
                              blurRadius: 6)
                        ]),
                    child: DefaultTextStyle(
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black87),
                      child: AnimatedTextKit(
                        key: ValueKey<int>(_currentSlide),
                        isRepeatingAnimation: false,
                        totalRepeatCount: 1,
                        animatedTexts: [
                          TypewriterAnimatedText(currentAnimatedText,
                              speed: const Duration(milliseconds: 40),
                              cursor: '|'),
                        ],
                        onFinished: () => _textAnimationCompleter?.complete(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // -------------------- GUESSTHELETTER MODE --------------------
    if (widget.fromPage == 'guesstheletter') {
      final labelCorrect = widget.isHindi == true ? 'सही' : 'Correct';
      final labelYour = widget.isHindi == true ? 'आपका उत्तर' : 'Your answer';
      final correctText = headerCorrect.isEmpty ? '-' : headerCorrect;
      final attemptedText = headerAttempted.isEmpty ? '-' : headerAttempted;
      final attemptedIsCorrect = headerCorrect.trim().isNotEmpty &&
          (headerCorrect.trim() == headerAttempted.trim());

      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isHindi == true ? 'AI विश्लेषण' : 'AI Explanation')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Question
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.12), blurRadius: 6)
                      ]),
                  child: Text(headerQuestion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                ),

                const SizedBox(height: 12),

                // Network image
                if (headerImageUrl != null)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Image.network(headerImageUrl!,
                        height: 120,
                        errorBuilder: (_, __, ___) => const SizedBox(
                            height: 120,
                            child: Center(child: Icon(Icons.broken_image)))),
                  ),

                const SizedBox(height: 12),

                // Options
                Row(
                  children: [
                    _buildOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildOptionCard(
                        label: labelYour,
                        content: attemptedText,
                        borderColor:
                            attemptedIsCorrect ? Colors.green : Colors.red,
                        showTick: attemptedIsCorrect,
                        isAttempt: true),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),

                // Animated writeup
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.10),
                              blurRadius: 6)
                        ]),
                    child: DefaultTextStyle(
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black87),
                      child: AnimatedTextKit(
                        key: ValueKey<int>(_currentSlide),
                        isRepeatingAnimation: false,
                        totalRepeatCount: 1,
                        animatedTexts: [
                          TypewriterAnimatedText(currentAnimatedText,
                              speed: const Duration(milliseconds: 40),
                              cursor: '|'),
                        ],
                        onFinished: () => _textAnimationCompleter?.complete(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // -------------------- MATCHING MODE --------------------
    if (widget.fromPage == 'matching') {
      final labelCorrect = widget.isHindi == true ? 'सही विकल्प' : 'Correct';
      final labelYour = widget.isHindi == true ? 'आपका उत्तर' : 'Your answer';
      final correctText = headerCorrect.isEmpty ? '-' : headerCorrect;
      final attemptedText = headerAttempted.isEmpty ? '-' : headerAttempted;
      final attemptedIsCorrect = headerCorrect.trim().isNotEmpty &&
          (headerCorrect.trim() == headerAttempted.trim());

      return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.isHindi == true ? 'AI विश्लेषण' : 'AI Explanation')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Question
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.12), blurRadius: 6)
                      ]),
                  child: Text(headerQuestion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),

                // Options
                Row(
                  children: [
                    _buildOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildOptionCard(
                        label: labelYour,
                        content: attemptedText,
                        borderColor:
                            attemptedIsCorrect ? Colors.green : Colors.red,
                        showTick: attemptedIsCorrect,
                        isAttempt: true),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),

                // Animated writeup
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.10),
                              blurRadius: 6)
                        ]),
                    child: DefaultTextStyle(
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black87),
                      child: AnimatedTextKit(
                        key: ValueKey<int>(_currentSlide),
                        isRepeatingAnimation: false,
                        totalRepeatCount: 1,
                        animatedTexts: [
                          TypewriterAnimatedText(currentAnimatedText,
                              speed: const Duration(milliseconds: 40),
                              cursor: '|'),
                        ],
                        onFinished: () => _textAnimationCompleter?.complete(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // -------------------- DEFAULT full-screen slides --------------------
    return Scaffold(
      appBar: AppBar(title: const Text('Video Lesson')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DefaultTextStyle(
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w500, color: Colors.black),
            child: AnimatedTextKit(
              key: ValueKey<int>(_currentSlide),
              isRepeatingAnimation: false,
              totalRepeatCount: 1,
              animatedTexts: [
                TypewriterAnimatedText(
                    done
                        ? (widget.isHindi == true
                            ? '— पाठ समाप्त —'
                            : '— End of lesson —')
                        : (_slides.isNotEmpty ? _slides[_currentSlide] : ''),
                    speed: const Duration(milliseconds: 50),
                    cursor: '|'),
              ],
              onFinished: () => _textAnimationCompleter?.complete(),
            ),
          ),
        ),
      ),
    );
  }
}
