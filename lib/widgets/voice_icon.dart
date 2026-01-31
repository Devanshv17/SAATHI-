import 'package:flutter/material.dart';
import '../services/tts_service.dart';

class VoiceIcon extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.volume_up_rounded,
        size: size,
        color: color ?? Theme.of(context).primaryColor,
      ),
      onPressed: () {
        // 'hi-IN' for Hindi, 'en-US' for English
        final lang = isHindi ? 'hi-IN' : 'en-US';
        TtsService().speak(text, language: lang);
      },
      tooltip: isHindi ? 'सुनने के लिए दबाएं' : 'Tap to listen',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
