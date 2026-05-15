import 'package:flutter/material.dart';

/// Scholesa brand colors and theme
class ScholesaColors {
  ScholesaColors._();

  // Logo-derived brand palette
  static const Color navy = Color(0xFF0F2D4B);
  static const Color sky = Color(0xFF0F96C3);
  static const Color teal = Color(0xFF006969);
  static const Color emerald = Color(0xFF1EA569);
  static const Color gold = Color(0xFFF0C31E);
  static const Color orange = Color(0xFFF0963C);
  static const Color coral = Color(0xFFF0695A);

  // Primary role colors
  static const Color learner = sky;
  static const Color educator = emerald;
  static const Color parent = teal;
  static const Color site = gold;
  static const Color hq = coral;
  static const Color partner = orange;
  static const Color purple = navy;

  // Background colors
  static const Color background = Color(0xFFF7FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FBF9);

  // Text colors
  static const Color textPrimary = navy;
  static const Color textSecondary = Color(0xFF40576C);
  static const Color textMuted = Color(0xFF6F8294);

  // Border colors
  static const Color border = Color(0xFFE4ECF2);
  static const Color borderLight = Color(0xFFF7FAFC);

  // Primary brand color
  static const Color primary = sky;
  static const Color primaryDark = navy;

  // Status colors
  static const Color success = emerald;
  static const Color warning = orange;
  static const Color error = coral;
  static const Color info = sky;

  // Pillar colors
  static const Color futureSkills = sky;
  static const Color leadership = emerald;
  static const Color impact = teal;

  // Role gradients
  static const LinearGradient missionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[sky, emerald, gold],
  );

  static const LinearGradient learnerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[sky, emerald],
  );

  static const LinearGradient educatorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[teal, emerald],
  );

  static const LinearGradient parentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[teal, sky],
  );

  static const LinearGradient siteGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[navy, teal],
  );

  static const LinearGradient hqGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[coral, orange],
  );

  static const LinearGradient partnerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[orange, coral],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[sky, emerald, gold],
  );

  // Feature gradients
  static const LinearGradient scheduleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[sky, teal],
  );

  static const LinearGradient billingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[emerald, teal],
  );

  static const LinearGradient safetyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[coral, orange],
  );

  /// Get color for a user role
  static Color forRole(String role) {
    switch (role.toLowerCase()) {
      case 'learner':
        return learner;
      case 'educator':
        return educator;
      case 'parent':
        return parent;
      case 'site':
        return site;
      case 'hq':
        return hq;
      case 'partner':
        return partner;
      default:
        return Colors.grey;
    }
  }

  /// Get gradient for a user role
  static LinearGradient gradientForRole(String role) {
    switch (role.toLowerCase()) {
      case 'learner':
        return learnerGradient;
      case 'educator':
        return educatorGradient;
      case 'parent':
        return parentGradient;
      case 'site':
        return siteGradient;
      case 'hq':
        return hqGradient;
      case 'partner':
        return partnerGradient;
      default:
        return const LinearGradient(
            colors: <Color>[Colors.grey, Colors.blueGrey]);
    }
  }
}

/// Extension to get role-related theme from a role name string
extension RoleThemeExtension on String {
  /// Get the gradient for this role name
  LinearGradient get roleGradient => ScholesaColors.gradientForRole(this);

  /// Get the color for this role name
  Color get roleColor => ScholesaColors.forRole(this);
}

/// Scholesa app theme
class ScholesaTheme {
  ScholesaTheme._();

  static ThemeData get light {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: ScholesaColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: ScholesaColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE8F6FB),
      onPrimaryContainer: ScholesaColors.navy,
      secondary: ScholesaColors.success,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFEAF7F1),
      onSecondaryContainer: ScholesaColors.teal,
      tertiary: ScholesaColors.warning,
      onTertiary: ScholesaColors.navy,
      tertiaryContainer: const Color(0xFFFFF0E3),
      onTertiaryContainer: ScholesaColors.navy,
      error: ScholesaColors.error,
      surface: ScholesaColors.surface,
      surfaceContainerLowest: ScholesaColors.background,
      surfaceContainerLow: ScholesaColors.surfaceVariant,
      surfaceContainer: const Color(0xFFE8F6FB),
      surfaceContainerHigh: const Color(0xFFE5F3F3),
      surfaceContainerHighest: const Color(0xFFF7FAFC),
      outline: const Color(0xFF6F8294),
      outlineVariant: ScholesaColors.border,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: ScholesaColors.background,
      canvasColor: scheme.surface,
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: ScholesaColors.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: ScholesaColors.surface,
        surfaceTintColor: ScholesaColors.primary.withValues(alpha: 0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ScholesaColors.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: ScholesaColors.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle: TextStyle(color: scheme.onPrimaryContainer),
      ),
    );
  }

  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: ScholesaColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: ScholesaColors.sky,
      onPrimary: Colors.white,
      primaryContainer: ScholesaColors.teal,
      onPrimaryContainer: const Color(0xFFE8F6FB),
      secondary: ScholesaColors.emerald,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF0A4C49),
      onSecondaryContainer: const Color(0xFFEAF7F1),
      tertiary: ScholesaColors.gold,
      onTertiary: ScholesaColors.navy,
      tertiaryContainer: const Color(0xFF6B5610),
      onTertiaryContainer: const Color(0xFFFFF7D6),
      error: ScholesaColors.coral,
      surface: const Color(0xFF0B253C),
      surfaceContainerLowest: const Color(0xFF061A2A),
      surfaceContainerLow: const Color(0xFF0F2D4B),
      surfaceContainer: const Color(0xFF12385A),
      surfaceContainerHigh: const Color(0xFF17456B),
      surfaceContainerHighest: const Color(0xFF1D527A),
      outline: const Color(0xFF64748B),
      outlineVariant: const Color(0xFF334155),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      canvasColor: scheme.surface,
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle: TextStyle(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

extension ScholesaThemeContext on BuildContext {
  ThemeData get schTheme => Theme.of(this);

  ColorScheme get schColorScheme => schTheme.colorScheme;

  Color get schSurface => schColorScheme.surface;

  Color get schSurfaceMuted => schColorScheme.surfaceContainerLow;

  Color get schSurfaceStrong => schColorScheme.surfaceContainerHigh;

  Color get schBorder => schColorScheme.outlineVariant;

  Color get schTextPrimary => schColorScheme.onSurface;

  Color get schTextSecondary => schColorScheme.onSurfaceVariant;
}
