// lib/utils/responsive.dart
// Responsive breakpoints and layout helpers for SAATHI.

import 'package:flutter/material.dart';

class Responsive {
  /// Mobile: width < 600
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  /// Tablet: 600 <= width < 1024
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1024;
  }

  /// Desktop: width >= 1024
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  /// Number of grid columns for the homepage game cards.
  /// Mobile → 1, Tablet → 2, Desktop → 2
  static int homeGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    return 2;
  }

  /// Number of grid columns for the team member tiles.
  /// Mobile → 2, Tablet → 3, Desktop → 4
  static int teamGridColumns(BuildContext context) {
    if (isMobile(context)) return 2;
    if (isTablet(context)) return 3;
    return 4;
  }

  /// Maximum content width for centering on large screens.
  static const double maxContentWidth = 1100;

  /// Maximum width for auth forms (login/register).
  static const double maxFormWidth = 520;

  /// Maximum width for game area (question + options).
  static const double maxGameWidth = 820;

  /// Horizontal padding that grows with the screen width.
  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1024) return 80;
    if (w >= 600) return 40;
    return 16;
  }

  /// Wrap [child] in a centered container capped at [maxWidth].
  static Widget centered({
    required Widget child,
    double maxWidth = maxContentWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
