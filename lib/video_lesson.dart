// lib/video_lesson.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';

/// Google Translate TTS (unofficial endpoint) with simple file caching.
/// NOTE: This uses an unofficial endpoint — it may change or be rate-limited.
/// To avoid very long pauses when the text is long, speak() will chunk the
/// input into smaller pieces (prefer sentence-aware splits) and play them
/// sequentially.
class GoogleTranslateTtsService {
  Future<String> _getCachePath(String text, String locale) async {
    final dir = await getApplicationDocumentsDirectory();
    final safe = '${locale}_${text.hashCode}';
    return '${dir.path}/$safe.mp3';
  }

  // Splits text into chunks ~<= maxChunkLength while trying to respect sentences.
  List<String> _chunkText(String text, {int maxChunkLength = 240}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    // Quick path for short text
    if (trimmed.length <= maxChunkLength) return [trimmed];

    // Split to sentences (keep punctuation)
    final sentences = trimmed.split(RegExp(r'(?<=[.?!])\s+'));
    final chunks = <String>[];
    var current = StringBuffer();

    for (final s in sentences) {
      if (current.isEmpty) {
        current.write(s);
      } else if ((current.length + 1 + s.length) <= maxChunkLength) {
        current.write(' ');
        current.write(s);
      } else {
        chunks.add(current.toString().trim());
        current = StringBuffer();
        current.write(s);
      }
    }
    if (current.isNotEmpty) {
      chunks.add(current.toString().trim());
    }

    // If any sentence itself is longer than maxChunkLength, fallback to splitting by words
    for (var i = 0; i < chunks.length; i++) {
      if (chunks[i].length > maxChunkLength) {
        final words = chunks[i].split(RegExp(r'\s+'));
        var sb = StringBuffer();
        final replaced = <String>[];
        for (final w in words) {
          if (sb.isEmpty) {
            sb.write(w);
          } else if ((sb.length + 1 + w.length) <= maxChunkLength) {
            sb.write(' ');
            sb.write(w);
          } else {
            replaced.add(sb.toString().trim());
            sb = StringBuffer();
            sb.write(w);
          }
        }
        if (sb.isNotEmpty) replaced.add(sb.toString().trim());
        // replace the overly-long chunk with the smaller ones
        chunks.removeAt(i);
        chunks.insertAll(i, replaced);
        i += replaced.length - 1;
      }
    }

    return chunks;
  }

  /// Speaks text using Google Translate TTS, caching the MP3s.
  /// `localeOverride` can be 'hi' or 'en' to force language.
  Future<void> speak(String text, {String? localeOverride}) async {
    if (text.trim().isEmpty) return;

    final guessedHindi = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    final isHindi = localeOverride == 'hi'
        ? true
        : (localeOverride == 'en' ? false : guessedHindi);
    final lang = localeOverride ?? (isHindi ? 'hi' : 'en');

    final chunks = _chunkText(text, maxChunkLength: 240);
    if (chunks.isEmpty) return;

    // Play sequentially. Use a single AudioPlayer per speak call to keep ordering.
    final player = AudioPlayer();
    for (final chunk in chunks) {
      final path = await _getCachePath(chunk, lang);
      final file = File(path);

      if (!await file.exists()) {
        final uri = Uri.parse(
          'https://translate.google.com/translate_tts'
          '?ie=UTF-8'
          '&q=${Uri.encodeComponent(chunk)}'
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
          debugPrint('Translate TTS failed (${res.statusCode}) for chunk.');
          // continue to next chunk instead of throwing to avoid stopping entire speech
          continue;
        }

        await file.writeAsBytes(res.bodyBytes, flush: true);
      }

      try {
        // await ensures chunks play sequentially
        await player.play(DeviceFileSource(path));
        // Wait until playback completes for this file:
        // AudioPlayer returns a Future that completes when playback begins, but not finishes.
        // To wait for completion, use onPlayerComplete. We'll await a Completer.
        final completer = Completer<void>();
        void onCompleteHandler(_) {
          if (!completer.isCompleted) completer.complete();
        }

        player.onPlayerComplete.listen(onCompleteHandler);
        // Some players may immediately call onComplete for short audio; guard with timeout.
        await completer.future.timeout(const Duration(seconds: 10),
            onTimeout: () {
          // timeout: continue to next chunk
          return;
        });
        // cancel subscription implicitly by letting listener go out of scope
      } catch (e) {
        debugPrint('TTS playback error (chunk): $e');
      }
    }

    // release player resources
    try {
      await player.dispose();
    } catch (_) {}
  }
}

/// VideoLesson widget
class VideoLesson extends StatefulWidget {
  final String script;
  final String? fromPage;
  final String? question;
  final String? correctOption;
  final String? attemptedOption;
  final List<String>? imageAssets; // letuscount
  final List<String>? leftAssets; // compare
  final List<String>? rightAssets; // compare
  final String? imageUrl; // guesstheletter (main question image)
  final DateTime? clockTime; // letustelltime
  final bool? isHindi;

  // --- Added optional image URLs for options ---
  final String? correctOptionImageUrl;
  final String? attemptedOptionImageUrl;

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
    this.correctOptionImageUrl,
    this.attemptedOptionImageUrl,
  }) : super(key: key);

  @override
  _VideoLessonState createState() => _VideoLessonState();
}

class _VideoLessonState extends State<VideoLesson> {
  late final GoogleTranslateTtsService _ttsService;

  // Header fields for special modes
  String headerQuestion = '';
  String headerCorrect = '';
  String headerAttempted = '';
  List<String> headerImages = [];
  List<String> headerLeft = [];
  List<String> headerRight = [];
  String? headerImageUrl;
  DateTime? headerClockTime;

  // Image url states for image-option cards
  String? headerCorrectOptionImageUrl;
  String? headerAttemptedOptionImageUrl;

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

    headerCorrectOptionImageUrl = widget.correctOptionImageUrl;
    headerAttemptedOptionImageUrl = widget.attemptedOptionImageUrl;

    debugPrint('VideoLesson init: fromPage=${widget.fromPage}');
    // Speak the entire explanation once after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playFullExplanation();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _playFullExplanation() async {
    try {
      final langOverride = widget.isHindi == true ? 'hi' : null;
      await _ttsService.speak(widget.script, localeOverride: langOverride);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  // Card for text-based options
  Widget _buildTextOptionCard({
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

  // Image-based option card
  Widget _buildImageOptionCard({
    required String label,
    required String title,
    required String? imageUrl,
    required Color color,
  }) {
    Widget content;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      content = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      );
    } else {
      content = Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      );
    }

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(child: content),
        ),
      ],
    );
  }

  Widget _buildImagesWrap(List<String> assets) {
    if (assets.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: assets
          .map((a) =>
              Image.asset(a, width: 40, height: 40, errorBuilder: (_, __, ___) {
                return const SizedBox(width: 40, height: 40);
              }))
          .toList(),
    );
  }

  // Reusable scrollable writeup container
  Widget _buildScrollableWriteup() {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.10), blurRadius: 6)
          ],
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Text(
              widget.script,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // -------------------- GUESSTHELETTER MODE (MODIFIED) --------------------
    if (widget.fromPage == 'guesstheletter') {
      final labelCorrect =
          widget.isHindi == true ? 'सही उत्तर' : 'Correct Answer';
      final labelYour = widget.isHindi == true ? 'आपका उत्तर' : 'Your Answer';
      final correctText = headerCorrect.isEmpty ? '-' : headerCorrect;
      final attemptedText = headerAttempted.isEmpty ? '-' : headerAttempted;

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

                // Network image for the question
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

                // Image option cards row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildImageOptionCard(
                      label: labelCorrect,
                      title: correctText,
                      imageUrl: headerCorrectOptionImageUrl,
                      color: Colors.green,
                    ),
                    _buildImageOptionCard(
                      label: labelYour,
                      title: attemptedText,
                      imageUrl: headerAttemptedOptionImageUrl,
                      color: Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),

                // Scrollable full explanation
                _buildScrollableWriteup(),
              ],
            ),
          ),
        ),
      );
    }

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
                    _buildTextOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildTextOptionCard(
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

                // Scrollable full explanation
                _buildScrollableWriteup(),
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
                    _buildTextOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildTextOptionCard(
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

                // Scrollable full explanation
                _buildScrollableWriteup(),
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
                    _buildTextOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildTextOptionCard(
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

                // Scrollable full explanation
                _buildScrollableWriteup(),
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
                    _buildTextOptionCard(
                        label: labelCorrect,
                        content: correctText,
                        borderColor: Colors.green,
                        showTick: true),
                    _buildTextOptionCard(
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

                // Scrollable full explanation
                _buildScrollableWriteup(),
              ],
            ),
          ),
        ),
      );
    }

    // -------------------- DEFAULT full-screen script view --------------------
    return Scaffold(
      appBar: AppBar(title: const Text('Video Lesson')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 6)
              ],
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: DefaultTextStyle(
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.black),
                  child: Text(widget.script),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
