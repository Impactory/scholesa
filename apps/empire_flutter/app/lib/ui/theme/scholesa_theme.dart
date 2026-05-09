import 'package:flutter/material.dart';

/// Scholesa brand colors and theme
class ScholesaColors {
  ScholesaColors._();

  // Primary role colors
  static const Color learner = Color(0xFF0E7490);
  static const Color educator = Color(0xFF059669);
  static const Color parent = Color(0xFF2563EB);
  static const Color site = Color(0xFFD97706);
  static const Color hq = Color(0xFFE11D48);
  static const Color partner = Color(0xFF4F46E5);
  static const Color purple = Color(0xFF6366F1);

  // Background colors
  static const Color background = Color(0xFFECFEFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0FDFA);

  // Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Border colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Primary brand color
  static const Color primary = Color(0xFF0E7490);
  static const Color primaryDark = Color(0xFF155E75);

  // Status colors
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Pillar colors
  static const Color futureSkills = Color(0xFF3B82F6);
  static const Color leadership = Color(0xFFE11D48);
  static const Color impact = Color(0xFF059669);

  // Role gradients
  static const LinearGradient missionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF0E7490), Color(0xFF059669)],
  );

  static const LinearGradient learnerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF0E7490), Color(0xFF06B6D4)],
  );

  static const LinearGradient educatorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF059669), Color(0xFF10B981)],
  );

  static const LinearGradient parentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF2563EB), Color(0xFF3B82F6)],
  );

  static const LinearGradient siteGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFD97706), Color(0xFFF59E0B)],
  );

  static const LinearGradient hqGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFE11D48), Color(0xFFF43F5E)],
  );

  static const LinearGradient partnerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF4F46E5), Color(0xFF6366F1)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF0E7490), Color(0xFF059669)],
  );

  // Feature gradients
  static const LinearGradient scheduleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF6366F1), Color(0xFF818CF8)],
  );

  static const LinearGradient billingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF059669), Color(0xFF10B981)],
  );

  static const LinearGradient safetyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFEF4444), Color(0xFFF87171)],
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
      primaryContainer: const Color(0xFFCFFAFE),
      onPrimaryContainer: const Color(0xFF164E63),
      secondary: ScholesaColors.success,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD1FAE5),
      onSecondaryContainer: const Color(0xFF064E3B),
      tertiary: ScholesaColors.warning,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFEF3C7),
      onTertiaryContainer: const Color(0xFF78350F),
      error: ScholesaColors.error,
      surface: ScholesaColors.surface,
      surfaceContainerLowest: ScholesaColors.background,
      surfaceContainerLow: ScholesaColors.surfaceVariant,
      surfaceContainer: const Color(0xFFE0F2FE),
      surfaceContainerHigh: const Color(0xFFEFF6FF),
      surfaceContainerHighest: const Color(0xFFF8FAFC),
      outline: const Color(0xFF94A3B8),
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
          borderRadius: BorderRadius.all(Radius.circular(16)),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          borderRadius: BorderRadius.circular(20),
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
      primary: const Color(0xFF67E8F9),
      onPrimary: const Color(0xFF083344),
      primaryContainer: const Color(0xFF164E63),
      onPrimaryContainer: const Color(0xFFCFFAFE),
      secondary: const Color(0xFF6EE7B7),
      onSecondary: const Color(0xFF022C22),
      secondaryContainer: const Color(0xFF064E3B),
      onSecondaryContainer: const Color(0xFFD1FAE5),
      tertiary: const Color(0xFFFCD34D),
      onTertiary: const Color(0xFF451A03),
      tertiaryContainer: const Color(0xFF78350F),
      onTertiaryContainer: const Color(0xFFFEF3C7),
      error: const Color(0xFFFCA5A5),
      surface: const Color(0xFF0F172A),
      surfaceContainerLowest: const Color(0xFF020617),
      surfaceContainerLow: const Color(0xFF111827),
      surfaceContainer: const Color(0xFF1E293B),
      surfaceContainerHigh: const Color(0xFF263244),
      surfaceContainerHighest: const Color(0xFF334155),
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
          borderRadius: const BorderRadius.all(Radius.circular(16)),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          borderRadius: BorderRadius.circular(20),
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
