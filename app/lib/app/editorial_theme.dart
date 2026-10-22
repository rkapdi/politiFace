import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Signal Brutalism" — Politiface's design system v1.0.
///
/// Source of truth: DESIGN.md at the repo root. Binding rules that shape
/// this file:
///   - The student app is a DARK surface; the instructor web portal is
///     light. ThemeMode defaults to dark (providers.dart).
///   - Colour is scarce: ~90% neutral, ~7% signal yellow, ~3% semantic.
///     Signal yellow is THE brand colour and carries the primary action.
///   - Semantic colours mean one thing, always: mint = correct, orange =
///     not yet, violet = locked in / terminal. Never decorative.
///   - No partisan colour: red and blue never appear as UI accents, state
///     colours, borders, or backgrounds. Party affiliation is a text
///     label. No exceptions.
///   - Flat only: no gradients, no blur, no glow. The only shadows are
///     hard offsets with zero blur (see BrutalButton and friends in the
///     neo kit).
///   - Type: Archivo (display), Inter (body), JetBrains Mono (data).
///     Weights 400 and 500 only; the display face carries the weight.
///
/// Naming note: the class keeps its historical name (EditorialPalette)
/// and constant names so the 18 consumer files keep compiling; the VALUES
/// are the DESIGN.md tokens. The semantic getters below (BrandColors) are
/// the preferred access path and are spec-compliant. A mechanical rename
/// lands with the screen-by-screen pass, not the token pass.
class EditorialPalette {
  // ── Dark surface (student app) ──────────────────────────────────────
  static const inkInverted = Color(0xFF0B0B0F); // page canvas
  static const slate = Color(0xFF17171C); // card surface
  static const slate2 = Color(0xFF26262E); // raised / segment
  static const line = Color(0xFF2A2A33); // border on dark
  static const lineDim = Color(0xFF3F3F4A); // thin separator
  static const mutedBorder = Color(0xFF4A4A55); // inactive control border
  static const textDim = Color(0xFF5F5F6B); // inactive segment text
  static const text3 = Color(0xFF6E6E7A); // metadata, captions
  static const text2 = Color(0xFFA3A3AD); // secondary text
  static const paperInverted = Color(0xFFF5F5F4); // primary text on dark
  static const ruleInverted = line; // legacy alias
  static const inkInvertedSubdued = text2; // legacy alias

  // ── Light surface (instructor / rare light mode) ────────────────────
  static const paper = Color(0xFFF5F5F4); // card-ish light surface
  static const canvasLt = Color(0xFFEDEDE8); // dashboard page canvas
  static const cardLt = Color(0xFFFFFFFF); // card surface on light
  static const ink = Color(0xFF0B0B0F); // text on light
  static const inkSubdued = Color(0xFF44444A); // secondary text on light
  static const rule = Color(0xFF000000); // brutalist border on light

  // ── Brand ───────────────────────────────────────────────────────────
  static const signal = Color(0xFFFFD400); // THE brand colour
  static const signalDk = Color(0xFFB89800); // pressed-state shadow

  // ── Semantic ────────────────────────────────────────────────────────
  static const correct = Color(0xFF3DD68C); // mint: correct / mastered
  static const notyet = Color(0xFFFF9D00); // orange: missed / needs review
  static const tier = Color(0xFF8B7CF6); // violet: locked in / unseen
  // AA-safe darkened siblings for the rare light-surface text use. On the
  // light instructor surface, state is encoded solid-vs-hollow black, not
  // colour (DESIGN.md 3.3); these exist for text that must be chromatic.
  static const correctOnLight = Color(0xFF1E7A4E);
  static const notyetOnLight = Color(0xFF9C5000);
  static const signalTextOnLight = Color(0xFF6E5E00);

  // ── Legacy constant names, remapped to spec tokens ──────────────────
  // actionRed is retired as a colour (partisan rule). Call sites that
  // meant "urgent / missed state" now get the not-yet orange; call sites
  // that meant "primary action" should use colorScheme.primary (signal).
  static const actionRed = notyet;
  static const actionRedDark = notyet;
  static const civicNavy = Color(0xFF17171C); // neutral fill on light
  static const civicNavyDark = text2; // neutral accent on dark
  static const ochre = signal;
  static const ochreDeep = signalTextOnLight;
  static const ochreDark = signal;
  static const civicGreen = correctOnLight;
  static const civicGreenDark = correct;
}

/// Brightness-aware accessors. Prefer these over raw constants: they pick
/// the AA-safe variant for the current surface.
extension BrandColors on ColorScheme {
  /// Historical name; now the NOT-YET / urgent state colour (orange).
  /// For the primary action colour use [primary] (signal yellow).
  Color get brandRed => brightness == Brightness.dark
      ? EditorialPalette.notyet
      : EditorialPalette.notyetOnLight;

  /// Historical name; now a NEUTRAL accent (no blue in this product).
  Color get brandNavy => brightness == Brightness.dark
      ? EditorialPalette.text2
      : EditorialPalette.civicNavy;

  /// Signal yellow: fills, strips, the one CTA per screen.
  Color get brandOchre => EditorialPalette.signal;

  /// Yellow-adjacent that survives as TEXT on the current surface.
  Color get brandOchreText => brightness == Brightness.dark
      ? EditorialPalette.signal
      : EditorialPalette.signalTextOnLight;

  Color get brandGreen => brightness == Brightness.dark
      ? EditorialPalette.correct
      : EditorialPalette.correctOnLight;

  /// Spec-named accessors for new code.
  Color get signal => EditorialPalette.signal;
  Color get correctState => brightness == Brightness.dark
      ? EditorialPalette.correct
      : EditorialPalette.correctOnLight;
  Color get notyetState => brightness == Brightness.dark
      ? EditorialPalette.notyet
      : EditorialPalette.notyetOnLight;
  Color get tierState => EditorialPalette.tier;
}

/// Light theme: the rare student-side light mode and any in-app surface
/// that mirrors the instructor dashboard. Yellow is the only chromatic.
ThemeData buildLightTheme() {
  const base = ColorScheme(
    brightness: Brightness.light,
    primary: EditorialPalette.signal,
    onPrimary: EditorialPalette.ink,
    secondary: EditorialPalette.civicNavy,
    onSecondary: Colors.white,
    tertiary: EditorialPalette.tier,
    onTertiary: EditorialPalette.ink,
    // No red in this product: destructive/error surfaces are ink-on-light
    // with heavy borders; validation text uses the AA-safe orange.
    error: EditorialPalette.notyetOnLight,
    onError: Colors.white,
    surface: EditorialPalette.canvasLt,
    onSurface: EditorialPalette.ink,
    onSurfaceVariant: EditorialPalette.inkSubdued,
    surfaceContainerLowest: EditorialPalette.cardLt,
    surfaceContainerLow: EditorialPalette.cardLt,
    surfaceContainer: Color(0xFFE4E4DF),
    surfaceContainerHigh: Color(0xFFDCDCD6),
    surfaceContainerHighest: Color(0xFFD2D2CC),
    outline: EditorialPalette.rule,
    outlineVariant: Color(0xFFC9C9C2),
  );
  return _themeFrom(base);
}

/// Dark theme: the student app's home surface.
ThemeData buildDarkTheme() {
  const base = ColorScheme(
    brightness: Brightness.dark,
    primary: EditorialPalette.signal,
    onPrimary: EditorialPalette.inkInverted,
    secondary: EditorialPalette.text2,
    onSecondary: EditorialPalette.inkInverted,
    tertiary: EditorialPalette.tier,
    onTertiary: EditorialPalette.inkInverted,
    error: EditorialPalette.notyet,
    onError: EditorialPalette.inkInverted,
    surface: EditorialPalette.inkInverted,
    onSurface: EditorialPalette.paperInverted,
    onSurfaceVariant: EditorialPalette.text2,
    surfaceContainerLowest: Color(0xFF08080B),
    surfaceContainerLow: EditorialPalette.slate,
    surfaceContainer: EditorialPalette.slate2,
    surfaceContainerHigh: Color(0xFF2E2E37),
    surfaceContainerHighest: Color(0xFF383841),
    outline: EditorialPalette.line,
    outlineVariant: EditorialPalette.lineDim,
  );
  return _themeFrom(base);
}

ThemeData _themeFrom(ColorScheme scheme) {
  final isLight = scheme.brightness == Brightness.light;

  // Three faces, two weights (DESIGN.md section 4): Archivo carries
  // display/headline/title at 500, Inter carries body at 400, JetBrains
  // Mono carries labels/metadata. Numerals are tabular wherever they
  // align.
  const tabular = [FontFeature.tabularFigures()];
  final display = GoogleFonts.archivoTextTheme();
  final body = GoogleFonts.interTextTheme();
  final mono = GoogleFonts.jetBrainsMonoTextTheme();

  final textTheme = TextTheme(
    displayLarge: display.displayLarge?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      height: 0.98,
      color: scheme.onSurface,
      fontFeatures: tabular,
    ),
    displayMedium: display.displayMedium?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: -0.3,
      height: 1,
      color: scheme.onSurface,
      fontFeatures: tabular,
    ),
    displaySmall: display.displaySmall?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
      fontFeatures: tabular,
    ),
    headlineLarge: display.headlineLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    ),
    headlineMedium: display.headlineMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    ),
    headlineSmall: display.headlineSmall?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    ),
    titleLarge: display.titleLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    ),
    titleMedium: display.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    ),
    titleSmall: display.titleSmall?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    ),
    bodyLarge: body.bodyLarge?.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: scheme.onSurface,
    ),
    bodyMedium: body.bodyMedium?.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: scheme.onSurface,
    ),
    bodySmall: body.bodySmall?.copyWith(
      fontWeight: FontWeight.w400,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: mono.labelLarge?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: scheme.onSurface,
    ),
    labelMedium: mono.labelMedium?.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0.7,
      color: scheme.onSurfaceVariant,
    ),
    labelSmall: mono.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 1.1,
      color: scheme.onSurfaceVariant,
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    // App bar: flat, bordered below. Radius zero everywhere.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      shape: Border(
        bottom: BorderSide(color: scheme.outline, width: 3),
      ),
    ),
    // The one yellow action per screen. The hard offset shadow + press
    // collapse live in BrutalButton (neo kit); this baseline keeps every
    // un-migrated FilledButton spec-legal: flat signal, zero radius.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: EditorialPalette.signal,
        foregroundColor: EditorialPalette.ink,
        shape: const RoundedRectangleBorder(),
        side: const BorderSide(width: 3), // black, per spec CTA border
        textStyle: textTheme.labelLarge?.copyWith(
          letterSpacing: 1.2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        side: const BorderSide(color: EditorialPalette.mutedBorder, width: 3),
        shape: const RoundedRectangleBorder(),
        textStyle: textTheme.labelLarge?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    ),
    // Cards: flat slate (dark) / white (light), 4px border, zero radius,
    // no elevation, no tint. Offset shadows are applied per-component,
    // never in a dense list (DESIGN.md density rule).
    cardTheme: CardTheme(
      color: isLight ? EditorialPalette.cardLt : EditorialPalette.slate,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outline, width: 4),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline,
      thickness: 1,
      space: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.onSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.surface,
        fontWeight: FontWeight.w500,
      ),
      shape: const RoundedRectangleBorder(),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor:
          isLight ? EditorialPalette.cardLt : EditorialPalette.slate,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: EditorialPalette.signal.withOpacity(0.16),
      labelTextStyle: WidgetStateProperty.all(
        textTheme.labelSmall?.copyWith(
          letterSpacing: 1.3,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
