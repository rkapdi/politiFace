import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Editorial Campaign" — Politiface's distinctive design system.
///
/// Inspiration: Saul Bass political design, Reuters newsroom serifs, modern
/// political magazine covers, vintage voting ballots. The goal is to feel
/// like a civic publication, not another Material-3 gradient-card app.
///
/// What's unique here:
///   - Typography pairs a transitional serif (Fraunces) with monospace
///     (JetBrains Mono). Most apps go sans+sans or serif+sans. The mono body
///     gives every screen a "this is an official document" weight.
///   - Palette is flat & deliberate: cream paper, near-black ink, one
///     campaign red for action, civic navy for trust, vintage ochre as
///     accent. No purple-gradient anything.
///   - Surface rules: hard 1.5px borders, sharp 4-6px corners, stamped-seal
///     button shadows (hard offset, no blur). Gradients are forbidden.
///   - Motion: 200-280ms easeOutCubic. No elastic bounces.
class EditorialPalette {
  // Light theme.
  static const paper = Color(0xFFF5F1E8);          // cream base
  static const ink = Color(0xFF1A1A1F);            // deep near-black
  static const inkSubdued = Color(0xFF5C5C66);     // secondary text
  static const rule = Color(0xFFD8D2C2);           // hairline border

  // Dark theme.
  static const inkInverted = Color(0xFF0F0F12);    // near-black base
  static const paperInverted = Color(0xFFEDE9DD);  // off-white text
  static const inkInvertedSubdued = Color(0xFF8A8A93);
  static const ruleInverted = Color(0xFF2A2A30);

  // Brand colors — same in both themes; saturation does the work.
  static const actionRed = Color(0xFFD6242C);      // campaign poster red
  static const civicNavy = Color(0xFF1E2A4A);      // trust
  static const ochre = Color(0xFFC9A05B);          // vintage paper highlight
  static const civicGreen = Color(0xFF2F6F4F);     // ledger / approval
}

/// Build the Editorial Campaign light theme.
ThemeData buildLightTheme() {
  final base = ColorScheme(
    brightness: Brightness.light,
    primary: EditorialPalette.actionRed,
    onPrimary: Colors.white,
    secondary: EditorialPalette.civicNavy,
    onSecondary: Colors.white,
    tertiary: EditorialPalette.ochre,
    onTertiary: EditorialPalette.ink,
    error: EditorialPalette.actionRed,
    onError: Colors.white,
    surface: EditorialPalette.paper,
    onSurface: EditorialPalette.ink,
    onSurfaceVariant: EditorialPalette.inkSubdued,
    surfaceContainerLowest: EditorialPalette.paper,
    surfaceContainerLow: const Color(0xFFEFEADA),
    surfaceContainer: const Color(0xFFE8E2CF),
    surfaceContainerHigh: const Color(0xFFE1DAC4),
    surfaceContainerHighest: const Color(0xFFD8D2BB),
    outline: EditorialPalette.rule,
    outlineVariant: const Color(0xFFE5DFCD),
  );
  return _themeFrom(base);
}

/// Build the Editorial Campaign dark theme.
ThemeData buildDarkTheme() {
  final base = ColorScheme(
    brightness: Brightness.dark,
    primary: EditorialPalette.actionRed,
    onPrimary: Colors.white,
    secondary: const Color(0xFF6B82B8), // navy reads lifted in dark
    onSecondary: EditorialPalette.inkInverted,
    tertiary: EditorialPalette.ochre,
    onTertiary: EditorialPalette.inkInverted,
    error: EditorialPalette.actionRed,
    onError: Colors.white,
    surface: EditorialPalette.inkInverted,
    onSurface: EditorialPalette.paperInverted,
    onSurfaceVariant: EditorialPalette.inkInvertedSubdued,
    surfaceContainerLowest: const Color(0xFF0B0B0E),
    surfaceContainerLow: const Color(0xFF161619),
    surfaceContainer: const Color(0xFF1C1C20),
    surfaceContainerHigh: const Color(0xFF24242A),
    surfaceContainerHighest: const Color(0xFF2C2C33),
    outline: EditorialPalette.ruleInverted,
    outlineVariant: const Color(0xFF1F1F25),
  );
  return _themeFrom(base);
}

ThemeData _themeFrom(ColorScheme scheme) {
  final isLight = scheme.brightness == Brightness.light;

  // Single family — Plus Jakarta Sans. Clean, sleek, slightly humanist
  // (warmer than Inter, less overused). Hierarchy comes from weight + size,
  // not from family-switching. Numbers get tabular alignment via the
  // OpenType `tnum` feature on numeric-heavy text styles.
  final base = GoogleFonts.plusJakartaSansTextTheme();
  const tabular = [FontFeature.tabularFigures()];

  final textTheme = TextTheme(
    // Display — for hero numbers / archetype reveals. Negative letterspacing
    // tightens the big sizes the way premium publications set them.
    displayLarge: base.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      height: 0.95,
      color: scheme.onSurface,
      fontFeatures: tabular,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      height: 1.0,
      color: scheme.onSurface,
      fontFeatures: tabular,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: scheme.onSurface,
      fontFeatures: tabular,
    ),
    // Headlines — for screen titles, section headers.
    headlineLarge: base.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: scheme.onSurface,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: scheme.onSurface,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: scheme.onSurface,
    ),
    // Titles — for card titles, list headers.
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
      color: scheme.onSurface,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: scheme.onSurface,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: scheme.onSurface,
    ),
    // Body — readable, modest weight.
    bodyLarge: base.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.45,
      color: scheme.onSurface,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.5,
      color: scheme.onSurface,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: scheme.onSurfaceVariant,
    ),
    // Labels — buttons / chips / metadata. Moderate letterspacing,
    // restrained — not the all-caps newspaper masthead treatment.
    labelLarge: base.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: scheme.onSurface,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: scheme.onSurfaceVariant,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: scheme.onSurfaceVariant,
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    // App bar — flat with a hairline underline. Reads like a newspaper
    // section header.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      shape: Border(
        bottom: BorderSide(color: scheme.outline, width: 1.5),
      ),
    ),
    // Buttons — stamped seal. Sharp corners, hard borders, no shadows
    // unless filled.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: textTheme.labelLarge?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.onSurface, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: textTheme.labelLarge?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    ),
    // Cards — flat with hard rules. No elevation. No surface tint.
    cardTheme: CardTheme(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline,
      thickness: 1.5,
      space: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.onSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.surface,
        fontWeight: FontWeight.w600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primary.withOpacity(isLight ? 0.14 : 0.22),
      labelTextStyle: WidgetStateProperty.all(
        textTheme.labelSmall?.copyWith(
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
