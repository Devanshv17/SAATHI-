import 'package:flutter/material.dart';
import '../services/tts_service.dart';

class VoiceIcon extends StatefulWidget {
  final String text;
  final bool isHindi;
  final double size;
  final Color? color;

  const VoiceIcon({
    Key? key,
    required this.text,
    required this.isHindi,
    this.size = 24.0,
    this.color,
  }) : super(key: key);

  @override
  State<VoiceIcon> createState() => _VoiceIconState();
}

class _VoiceIconState extends State<VoiceIcon> {
  // This automatically runs the moment you hit the 'back' button!
  @override
  void dispose() {
    TtsService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.volume_up_rounded,
        size: widget.size,
        color: widget.color ?? Theme.of(context).primaryColor,
      ),
      onPressed: () {
        final lang = widget.isHindi ? 'hi-IN' : 'en-US';
        TtsService().speak(widget.text, language: lang);
      },
      tooltip: widget.isHindi ? 'सुनने के लिए दबाएं' : 'Tap to listen',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
