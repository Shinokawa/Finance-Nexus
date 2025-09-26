import 'package:flutter/cupertino.dart';

class QHColors {
  QHColors._();

  static const background = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7), // System Gray 6
    darkColor: Color(0xFF1C1C1E),
  );

  static const groupedBackground = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE5E5EA), // System Gray 5
    darkColor: Color(0xFF2C2C2E),
  );

  static const cardBackground = CupertinoDynamicColor.withBrightness(
    color: CupertinoColors.white,
    darkColor: Color(0xFF2C2C2E),
  );

  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF7F8FA),
    darkColor: Color(0xFF1C1C1E),
  );

  static const primary = CupertinoColors.activeBlue;
  static const profit = CupertinoColors.systemRed;    // 涨：红色
  static const loss = CupertinoColors.systemGreen;    // 跌：绿色
}

class QHSpacing {
  QHSpacing._();

  static const double pageHorizontal = 16;
  static const double pageVertical = 20;
  static const double cardSpacing = 20;
  static const double cornerRadius = 10;
}

class QHTypography {
  QHTypography._();

  static const largeTitle = TextStyle(
    inherit: false,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
  );

  static const title1 = TextStyle(
    inherit: false,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.36,
  );

  static const title3 = TextStyle(
    inherit: false,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.35,
  );

  static const body = TextStyle(
    inherit: false,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
  );

  static const subheadline = TextStyle(
    inherit: false,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
  );

  static const footnote = TextStyle(
    inherit: false,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
  );
}

class QHTheme {
  QHTheme._();

  static CupertinoThemeData theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final labelColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: QHColors.primary,
      barBackgroundColor:
          isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground,
      scaffoldBackgroundColor: QHColors.background,
      textTheme: CupertinoTextThemeData(
        navLargeTitleTextStyle: QHTypography.largeTitle.copyWith(
          inherit: false,
          color: labelColor,
          decoration: TextDecoration.none,
        ),
        navTitleTextStyle: QHTypography.body.copyWith(
          inherit: false,
          fontWeight: FontWeight.w600,
          color: labelColor,
          decoration: TextDecoration.none,
        ),
        primaryColor: QHColors.primary,
        textStyle: QHTypography.body.copyWith(
          inherit: false,
          color: labelColor,
          decoration: TextDecoration.none,
        ),
        tabLabelTextStyle: QHTypography.subheadline.copyWith(
          inherit: false,
          color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
