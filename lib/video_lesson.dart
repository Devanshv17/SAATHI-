// lib/video_lesson.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';

import 'ai.dart';
import 'widgets/voice_icon.dart';
import 'services/tts_service.dart';

class GoogleTranslateTtsService {}

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

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class _VideoLessonState extends State<VideoLesson> {
  final _ttsService = TtsService();
  final _aiService = AiService();

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

  // Chat state
  final List<_ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;
  bool _showChat = false;

  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playFullExplanation();
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _sendFollowUp() async {
    final msg = _chatController.text.trim();
    if (msg.isEmpty || _isChatLoading) return;
    _chatController.clear();
    setState(() {
      _chatMessages.add(_ChatMessage(text: msg, isUser: true));
      _isChatLoading = true;
    });
    _scrollChatToBottom();
    try {
      final reply = await _aiService.sendFollowUp(
        question: headerQuestion,
        correctAnswer: headerCorrect,
        userAnswer: headerAttempted,
        explanation: widget.script,
        userMessage: msg,
        forceHindi: widget.isHindi ?? false,
      );
      if (mounted) {
        setState(() {
          _chatMessages.add(_ChatMessage(text: reply, isUser: false));
          _isChatLoading = false;
        });
        _scrollChatToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add(_ChatMessage(
            text: widget.isHindi == true
                ? 'माफ़ करें, कुछ गड़बड़ हुई। फिर से कोशिश करें।'
                : 'Sorry, something went wrong. Please try again.',
            isUser: false,
          ));
          _isChatLoading = false;
        });
        _scrollChatToBottom();
      }
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildChatSection() {
    final isHindi = widget.isHindi == true;
    final hintText = isHindi ? 'कोई सवाल पूछें...' : 'Ask a follow-up question...';
    final chatLabel = isHindi ? 'AI से और जानें' : 'Learn more with AI';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showChat = !_showChat),
          icon: Icon(
            _showChat ? Icons.keyboard_arrow_up : Icons.chat_bubble_outline,
            color: const Color(0xFF6541EF),
          ),
          label: Text(
            _showChat
                ? (isHindi ? 'चैट बंद करें' : 'Close chat')
                : chatLabel,
            style: const TextStyle(
              color: Color(0xFF6541EF),
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF6541EF), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        if (_showChat) ...[
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6541EF).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 6),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: _chatMessages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              isHindi
                                  ? 'इस सवाल के बारे में कुछ भी पूछें!'
                                  : 'Ask anything about this question!',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _chatScrollController,
                          padding: const EdgeInsets.all(10),
                          itemCount: _chatMessages.length,
                          itemBuilder: (_, i) {
                            final m = _chatMessages[i];
                            return Align(
                              alignment: m.isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.72,
                                ),
                                decoration: BoxDecoration(
                                  color: m.isUser
                                      ? const Color(0xFF6541EF)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  m.text,
                                  style: TextStyle(
                                    color: m.isUser ? Colors.white : Colors.black87,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_isChatLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _sendFollowUp(),
                          textInputAction: TextInputAction.send,
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _sendFollowUp,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6541EF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _playFullExplanation() async {
    try {
      final lang = widget.isHindi == true ? 'hi-IN' : 'en-IN';
      await _ttsService.speak(widget.script, language: lang);
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
            BoxShadow(color: Colors.grey.withValues(alpha: 0.12), blurRadius: 6)
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
                color: Colors.black.withValues(alpha: 0.1),
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

  // Reusable scrollable writeup container with VoiceIcon embedded!
  Widget _buildScrollableWriteup() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.10), blurRadius: 6)
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.script,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          VoiceIcon(
            text: widget.script,
            isHindi: widget.isHindi ?? false,
            size: 30,
            color: Colors.blue,
          ),
        ],
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            color: Colors.grey.withValues(alpha: 0.12), blurRadius: 6)
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

                _buildScrollableWriteup(),
                _buildChatSection(),
                const SizedBox(height: 16),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          color: Colors.grey.withValues(alpha: 0.12), blurRadius: 6)
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
                  Center(
                    child: Container(
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

                _buildScrollableWriteup(),
                _buildChatSection(),
                const SizedBox(height: 16),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            color: Colors.grey.withValues(alpha: 0.12), blurRadius: 6)
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

                _buildScrollableWriteup(),
                _buildChatSection(),
                const SizedBox(height: 16),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            color: Colors.grey.withValues(alpha: 0.12), blurRadius: 6)
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

                _buildScrollableWriteup(),
                _buildChatSection(),
                const SizedBox(height: 16),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            color: Colors.grey.withValues(alpha: 0.12), blurRadius: 6)
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

                _buildScrollableWriteup(),
                _buildChatSection(),
                const SizedBox(height: 16),
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
                BoxShadow(color: Colors.grey.withValues(alpha: 0.12), blurRadius: 6)
              ],
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                  children: [
                    Expanded(
                      child: DefaultTextStyle(
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Colors.black),
                        child: Text(widget.script),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // VoiceIcon added to the fallback view as well
                    VoiceIcon(
                      text: widget.script,
                      isHindi: widget.isHindi ?? false,
                      size: 30,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
