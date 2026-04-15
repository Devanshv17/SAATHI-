import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';
import 'voice_icon.dart';

class GameCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final int correctScore;
  final int incorrectScore;
  final bool isHindi;
  final VoidCallback onPlay;
  final String playLabel;
  final String continueLabel;

  const GameCard({
    Key? key,
    required this.title,
    required this.imagePath,
    required this.correctScore,
    required this.incorrectScore,
    required this.isHindi,
    required this.onPlay,
    required this.playLabel,
    required this.continueLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasPlayed = (correctScore + incorrectScore) > 0;
    // Adapt image circle size based on screen width
    final double imgSize = MediaQuery.of(context).size.width >= 600 ? 80 : 70;

    return Container(
      // No fixed width — fills parent grid cell or column width
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(100, 191, 235, 239),
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: imgSize,
            height: imgSize,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 1),
              borderRadius: BorderRadius.circular(50),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment
                      .start, // Aligns icon to the top if text wraps
                  children: [
                    // WRAP THE TEXT WIDGET IN AN EXPANDED WIDGET HERE
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.gameTitle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    VoiceIcon(text: title, isHindi: isHindi, size: 20),
                  ],
                ),
                if (hasPlayed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$correctScore',
                            style: AppTextStyles.scoreCorrect,
                          ),
                          const TextSpan(
                            text: '  |  ',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '$incorrectScore',
                            style: AppTextStyles.scoreIncorrect,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonBackgroundLight,
                      ),
                      onPressed: onPlay,
                      child: Text(
                        hasPlayed ? continueLabel : playLabel,
                        style: AppTextStyles.gameButton,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
