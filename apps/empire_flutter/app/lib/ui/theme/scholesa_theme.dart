import 'package:flutter/material.dart';

/// Scholesa brand colors and theme
class ScholesaColors {
  ScholesaColors._();

  // Primary role colors
  static const Color learner = Color(0xFF10B981);
  static const Color educator = Color(0xFF059669);
  static const Color parent = Color(0xFFDB2777);
  static const Color site = Color(0xFF7C3AED);
  static const Color hq = Color(0xFF1E40AF);
  static const Color partner = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);

  // Background colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Border colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Primary brand color
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF059669);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Pillar colors
  static const Color futureSkills = Color(0xFF3B82F6);
  static const Color leadership = Color(0xFF8B5CF6);
  static const Color impact = Color(0xFF10B981);

  // Role gradients
  static const LinearGradient missionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient learnerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient educatorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF059669), Color(0xFF10B981)],
  );

  static const LinearGradient parentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFDB2777), Color(0xFFEC4899)],
  );

  static const LinearGradient siteGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF7C3AED), Color(0xFF8B5CF6)],
  );

  static const LinearGradient hqGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF1E40AF), Color(0xFF3B82F6)],
  );

  static const LinearGradient partnerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF10B981), Color(0xFF059669)],
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
        return const LinearGradient(colors: <Color>[Colors.grey, Colors.blueGrey]);
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
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ScholesaColors.learner,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ScholesaColors.learner,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Inter',
    );
  }
}
