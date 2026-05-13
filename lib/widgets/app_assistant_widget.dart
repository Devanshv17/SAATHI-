import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../language_notifier.dart';
import '../services/assistant_service.dart';
import '../game.dart';
import '../compare.dart';
import '../guesstheletter.dart';
import '../letuscount.dart';
import '../letustelltime.dart';
import '../matching.dart';

class AppAssistantWidget extends StatefulWidget {
  final ValueNotifier<bool> visible;
  final GlobalKey<NavigatorState> navigatorKey;

  const AppAssistantWidget({
    Key? key,
    required this.visible,
    required this.navigatorKey,
  }) : super(key: key);

  @override
  State<AppAssistantWidget> createState() => _AppAssistantWidgetState();
}

class _AppAssistantWidgetState extends State<AppAssistantWidget>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF6541EF);

  final _service = AppAssistantService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];

  bool _isOpen = false;
  bool _isLoading = false;

  late final AnimationController _panelAnim;
  late final Animation<Offset> _slideAnim;

  static const _quickActions = [
    'What games are in this app?',
    'How do I start playing?',
    'Which game teaches counting?',
    'Show me my profile',
  ];

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelAnim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _panelAnim.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openChat() {
    setState(() => _isOpen = true);
    _panelAnim.forward();
  }

  void _closeChat() {
    _panelAnim.reverse().then((_) {
      if (mounted) setState(() => _isOpen = false);
    });
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isLoading) return;
    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': msg});
      _isLoading = true;
    });
    _scrollToBottom();

    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;

    try {
      final response = await _service.sendMessage(
        _messages.sublist(0, _messages.length - 1),
        msg,
        isHindi: isHindi,
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'text': response.text});
          _isLoading = false;
        });
        _scrollToBottom();

        if (response.navTarget != null) {
          await Future.delayed(const Duration(milliseconds: 900));
          if (mounted) _navigate(response.navTarget!);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': 'Oops! Something went wrong. Please try again.',
          });
          _isLoading = false;
        });
      }
    }
  }

  void _navigate(String target) {
    final nav = widget.navigatorKey.currentState;
    if (nav == null) return;
    _closeChat();

    Future.delayed(const Duration(milliseconds: 350), () {
      if (target == 'profile') {
        nav.pushNamed('/profile');
      } else if (target == 'about') {
        nav.pushNamed('/about');
      } else if (target == 'team') {
        nav.pushNamed('/team');
      } else if (target == 'home') {
        nav.popUntil((r) => r.isFirst);
      } else if (target.startsWith('game:')) {
        final title = target.substring(5);
        final isHindi =
            Provider.of<LanguageNotifier>(context, listen: false).isHindi;
        final page = _gamePage(title, isHindi);
        nav.push(MaterialPageRoute(builder: (_) => page));
      }
    });
  }

  Widget _gamePage(String title, bool isHindi) {
    switch (title) {
      case 'Compare':
        return ComparePage(gameTitle: title, isHindi: isHindi);
      case 'Guess the Letter':
      case 'Shape Knowledge':
        return GuessTheLetterPage(gameTitle: title, isHindi: isHindi);
      case 'Let us Count':
        return LetUsCountPage(gameTitle: title, isHindi: isHindi);
      case 'Let us Tell Time':
        return LetUsTellTimePage(gameTitle: title, isHindi: isHindi);
      case 'Number Name Matching':
      case 'Name Number Matching':
      case 'Alphabet Knowledge':
      case 'Left Middle Right':
        return MatchingPage(gameTitle: title, isHindi: isHindi);
      default:
        return GamePage(gameTitle: title, isHindi: isHindi);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.visible,
      builder: (context, isVisible, _) {
        if (!isVisible) return const SizedBox.shrink();
        return Stack(
          children: [
            // Backdrop
            if (_isOpen)
              GestureDetector(
                onTap: _closeChat,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.38),
                ),
              ),

            // Slide-up chat panel
            if (_isOpen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.82,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildPanel(context),
                ),
              ),

            // Floating button
            Positioned(
              bottom: 24,
              right: 20,
              child: _buildFab(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFab() {
    return GestureDetector(
      onTap: _isOpen ? _closeChat : _openChat,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF8B65FF), _purple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isOpen
              ? const Icon(Icons.close, color: Colors.white, size: 26, key: ValueKey('close'))
              : const Icon(Icons.auto_awesome, color: Colors.white, size: 26, key: ValueKey('open')),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessages()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B65FF), _purple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saathi Assistant',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text('Ask me anything about the app!',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _closeChat,
            child: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return _buildWelcome();
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        final m = _messages[i];
        final isUser = m['role'] == 'user';
        return _buildBubble(m['text']!, isUser);
      },
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👋 Hi! I\'m Saathi\'s AI assistant.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('I can explain games, help you navigate, or answer any questions about the app.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          const Text('Try asking:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickActions.map((q) {
              return GestureDetector(
                onTap: () => _send(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.08),
                    border: Border.all(color: _purple.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(q,
                      style: const TextStyle(
                          color: _purple, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? _purple : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _dot(i)),
        ),
      ),
    );
  }

  Widget _dot(int i) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + i * 150),
      builder: (_, v, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withValues(alpha: 0.4 + 0.6 * v),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _send,
                textInputAction: TextInputAction.send,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Ask me anything...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _send(_controller.text),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(
                  color: _purple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
