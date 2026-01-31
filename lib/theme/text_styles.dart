import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get header => GoogleFonts.trocchi(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      );

  static TextStyle get subHeader => GoogleFonts.trocchi(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      );

  static TextStyle get body => GoogleFonts.trocchi(
        fontSize: 16,
        color: AppColors.tealDark,
      );
      
  static TextStyle get buttonText => GoogleFonts.trocchi(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      );
      
  static const TextStyle gameTitle = TextStyle(
      fontSize: 16, 
      color: AppColors.primary, 
      fontWeight: FontWeight.bold,
      fontFamily: 'MyCustom2'
  );
  
  static const TextStyle scoreCorrect = TextStyle(
      color: AppColors.correctGreen,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      fontFamily: 'MyCustomFont'
  );
  
  static const TextStyle scoreIncorrect = TextStyle(
      color: AppColors.incorrectRed,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      fontFamily: 'MyCustomFont'
  );
  
  static const TextStyle gameButton = TextStyle(
      color: AppColors.primary, 
      fontSize: 14,
      fontFamily: 'MyCustomFont',
      fontWeight: FontWeight.normal
  );
}
