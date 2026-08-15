// ============================================================================
//  Jota — design tokens (phone)
//
//  The sibling of firmware/src/ui/theme.h. Same design language, different
//  medium: the device is 200x200 and 1-bit, the phone is ~400pt wide with a
//  real compositor and two colour schemes. What carries across is not the
//  pixel values — it is the *rules*:
//
//    - monospace for every figure and identifier, sans for prose only
//    - near-monochrome; ink on paper, one signal colour used twice
//    - stadiums (radius = h/2) and circles are the only shapes
//    - selection is shown by INVERSION, never by a tint
//    - one hairline of chrome, then whitespace
//
//  Single source of truth. Screens name POSITIONS AND ROLES FROM THIS FILE,
//  never their own magic numbers — the same discipline theme.h enforces, and
//  for the same reason: the device's two adjacent screens once disagreed about
//  the size of the same datum because the fonts were named by metric.
// ============================================================================
import 'package:flutter/material.dart';

// ---- Palette ---------------------------------------------------------------
// The device has two colours. The phone gets six, and five of them are greys.
// Everything structural resolves to `ink` or `bg`; the greys exist only so a
// hairline can be a hairline instead of a black bar, and so secondary metadata
// can recede without changing size.
@immutable
class JotaColors extends ThemeExtension<JotaColors> {
  const JotaColors({
    required this.ink,
    required this.bg,
    required this.inkMuted,
    required this.rule,
    required this.field,
    required this.signal,
  });

  /// Foreground. Everything that carries meaning is this colour.
  final Color ink;

  /// Background. Paper.
  final Color bg;

  /// Metadata that must be present but must not compete: timestamps under a
  /// heading, byte counts, the secondary half of a status line.
  final Color inkMuted;

  /// Hairlines. The only line weight in the app.
  final Color rule;

  /// The interior of an inactive input. A hair off the background, never a box.
  final Color field;

  /// The ONE accent. It appears in exactly two places in the whole app:
  ///   1. the pending-notes dot — "the device is holding something for you"
  ///   2. error text — a failed CRC, a rejected API key
  /// It is never used for emphasis, never for a chip, never for a button.
  /// If you are reaching for it for a third reason, the answer is no.
  final Color signal;

  /// Ink knocked out of a filled shape. Selection inverts, so a selected row's
  /// label is drawn in the background colour.
  Color get onInk => bg;

  /// Text-selection wash. A literal rather than a computed alpha so the token
  /// survives Flutter's ongoing churn around Color.withOpacity/withValues.
  Color get selection =>
      brightnessIsDark ? const Color(0x33EDE6DA) : const Color(0x3323201C);

  bool get brightnessIsDark => bg.computeLuminance() < 0.5;

  // The phone is not a 1-bit panel, so it does not have to be pure black on
  // pure white. Paper is a warm cream and ink is a warm espresso — the same
  // near-monochrome the device reads as, but the temperature the e-paper
  // actually has in the hand. The greys and the one terracotta accent warm to
  // match. Nothing structural changed: everything still resolves to ink or bg.
  static const JotaColors light = JotaColors(
    ink: Color(0xFF23201C), // espresso
    bg: Color(0xFFF6F1E8), // paper
    inkMuted: Color(0xFF8B8177), // warm taupe
    rule: Color(0xFFE4DCD0),
    field: Color(0xFFEFE8DC),
    signal: Color(0xFFA8452C), // clay
  );

  static const JotaColors dark = JotaColors(
    ink: Color(0xFFEDE6DA), // warm paper-white
    bg: Color(0xFF16130F), // warm charcoal
    inkMuted: Color(0xFF968C7E),
    rule: Color(0xFF302A22),
    field: Color(0xFF1E1A15),
    signal: Color(0xFFDD6D4C),
  );

  @override
  JotaColors copyWith({
    Color? ink,
    Color? bg,
    Color? inkMuted,
    Color? rule,
    Color? field,
    Color? signal,
  }) {
    return JotaColors(
      ink: ink ?? this.ink,
      bg: bg ?? this.bg,
      inkMuted: inkMuted ?? this.inkMuted,
      rule: rule ?? this.rule,
      field: field ?? this.field,
      signal: signal ?? this.signal,
    );
  }

  @override
  JotaColors lerp(ThemeExtension<JotaColors>? other, double t) {
    if (other is! JotaColors) return this;
    return JotaColors(
      ink: Color.lerp(ink, other.ink, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      field: Color.lerp(field, other.field, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
    );
  }
}

// ---- Grid ------------------------------------------------------------------
// The device's base unit is 4px on a 200px canvas — a 1/50 module. The phone
// keeps the 4pt unit (it is also Material's) and scales the margin to hold the
// same optical inset: 14/200 on the panel, 20/390 is close enough on a phone
// once you account for the panel being held at arm's length.
abstract final class JotaGrid {
  static const double unit = 4;

  static const double margin = 20; // left / right, matches theme.h MARGIN
  static const double gapS = 6; // theme.h GAP_S
  static const double gapM = 12; // theme.h GAP_M
  static const double gapL = 20; // theme.h GAP_L
  static const double gapXL = 32; // no panel equivalent; the phone has room

  /// Status label baseline block. The device puts the label at y=22 with the
  /// rule at y=28; the phone keeps the proportion but respects the safe area.
  static const double statusHeight = 34;
  static const double statusRuleGap = 6;

  /// Hairline. One weight, everywhere. Physical-pixel thin where possible.
  static const double hairline = 1;
}

// ---- Rows ------------------------------------------------------------------
// One list component, exactly as on the device. Radius is ALWAYS height/2, so
// every row is a stadium and there is no second corner radius in the app.
abstract final class JotaRows {
  /// The device uses 22px because six rows is its hard ceiling. The phone uses
  /// 48 because that is the minimum comfortable touch target, and because a
  /// stadium shorter than that reads as a chip rather than a row.
  static const double height = 48;
  static const double gap = 8;

  /// Compact variant for inline controls (PLAY, SAVE, the tag pills).
  static const double heightCompact = 36;

  /// A prominent primary CTA — the one "do this now" button on a focused
  /// screen (pair, an empty-state action). Taller so it carries the screen.
  static const double heightTall = 56;

  static double radiusOf(double height) => height / 2;

  static BorderRadius borderRadiusOf(double height) =>
      BorderRadius.all(Radius.circular(radiusOf(height)));
}

// ---- Indicators ------------------------------------------------------------
abstract final class JotaIndicators {
  /// theme.h PROGRESS_H is 10 on a 200px panel. Same proportion, and it is
  /// still a stadium: an outlined stadium with a filled stadium inside it.
  static const double progressHeight = 12;

  /// theme.h CIRCLE_R / CIRCLE_STROKE / CIRCLE_STROKE_ACTIVE. The ring's outer
  /// edge never moves between idle and active — the annulus thickens inward.
  static const double ringRadius = 52;
  static const double ringStroke = 3;
  static const double ringStrokeActive = 8;
  static const double dotRadius = 4;

  /// The pending-notes dot in the status line.
  static const double signalDot = 7;
}

// ---- Cards -----------------------------------------------------------------
// The ONE non-stadium radius in the whole app, and the only sanctioned rounded
// rectangle: the onboarding/splash hero that holds a device render. Everything
// else is a stadium (radius = h/2). The card is still flat — a hairline and a
// fill, never a shadow — because the device is a flat panel and so is this.
abstract final class JotaCards {
  /// 16, from the drawing. It was 20, which is enough curvature to read as its
  /// own soft-UI idiom rather than as a panel with its corners taken off — and
  /// on a card that sits beside 48pt stadiums, the two radii started arguing
  /// about what shape language this app is in.
  static const double radius = 16;
}

// ---- Motion ----------------------------------------------------------------
// E-paper cannot animate, so the device has no motion language to inherit. The
// phone gets the minimum that keeps state changes legible, and nothing that
// draws attention to itself. No bounces, no scale, no colour transitions.
abstract final class JotaMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeOutCubic;
}

// ---- Type ------------------------------------------------------------------
// Named for their JOB, not their metrics — the same rule theme.h states, and
// the same five roles plus the brand asset:
//
//   label    status label, row labels, buttons        (mono, bold)
//   reading  status value, metadata, secondary figures (mono, regular)
//   figure   the ONE live number on a screen           (mono, bold, large)
//   display  terminal confirmation, pair codes         (mono, bold, largest)
//   headline onboarding / splash headlines ONLY        (serif)
//   prose    transcripts ONLY                          (sans)
//   wordmark JOTA — a brand asset, not a style
//
// The split is not decoration. Monospace makes a figure read as a measurement
// and keeps columns aligned without a layout pass; at transcript width the same
// face fits ~15 characters per line, which shreds a paragraph. So: sans for
// prose, mono for everything else. This is the strongest single signal that the
// app and the device are one product.
abstract final class JotaFonts {
  /// Three bundled faces, one per job. The family strings MATCH each font's
  /// internal name — on iOS the bundled font is resolved by that, not by an
  /// arbitrary pubspec alias.
  static const String serif = 'IBM Plex Serif'; // headlines + wordmark
  static const String sans = 'IBM Plex Sans'; //   labels, buttons, prose

  /// Figures are monospace so codes and columns align without a layout pass.
  /// BUNDLED rather than left to the platform: the fallback resolved to Roboto
  /// Mono on Android and SF Mono on iOS, so the same timer rendered at two
  /// different widths and the zero-padded figures the design depends on did not
  /// line up across devices.
  static const String mono = 'IBM Plex Mono';

  /// Arabic note text. Roughly half of what gets recorded is Arabic, and
  /// neither of the previous faces carried a single Arabic glyph — so those
  /// notes rendered in whatever the phone happened to fall back to, which is a
  /// different design on every handset. Plex Arabic shares the skeleton with
  /// the Latin faces, so a mixed list reads as one product.
  ///
  /// Only the note's WORDS use it. Dates, tags and chrome follow the app
  /// language, not the note's — see docs/brand.md.
  static const String arabic = 'IBM Plex Sans Arabic';

  /// Every family here falls back to Plex first: a missing glyph should land on
  /// a sibling of the same design before it lands on a system face.
  static const List<String> serifFallback = <String>[
    'IBM Plex Sans',
    'Georgia',
    'Times New Roman',
    'serif',
  ];

  static const List<String> sansFallback = <String>[
    'IBM Plex Sans Arabic',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static const List<String> monoFallback = <String>[
    'IBM Plex Sans',
    'Roboto Mono',
    'SF Mono',
    'Menlo',
    'DejaVu Sans Mono',
    'Courier New',
    'monospace',
  ];

  static const List<String> arabicFallback = <String>[
    'IBM Plex Sans',
    'Noto Sans Arabic',
    'Geeza Pro',
    'sans-serif',
  ];
}

@immutable
class JotaType extends ThemeExtension<JotaType> {
  const JotaType({
    required this.label,
    required this.reading,
    required this.figure,
    required this.display,
    required this.headline,
    required this.prose,
    required this.wordmark,
  });

  final TextStyle label;
  final TextStyle reading;
  final TextStyle figure;
  final TextStyle display;

  /// Serif, large. The one warm, elegant voice in the app — reserved for
  /// onboarding and splash headlines. Never a figure, never an identifier.
  final TextStyle headline;

  final TextStyle prose;
  final TextStyle wordmark;

  static const TextStyle _mono = TextStyle(
    fontFamily: JotaFonts.mono,
    fontFamilyFallback: JotaFonts.monoFallback,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle _sans = TextStyle(
    fontFamily: JotaFonts.sans,
    fontFamilyFallback: JotaFonts.sansFallback,
  );

  static const TextStyle _serif = TextStyle(
    fontFamily: JotaFonts.serif,
    fontFamilyFallback: JotaFonts.serifFallback,
  );

  static JotaType of(Color ink) {
    return JotaType(
      // Three voices, by role — all IBM Plex:
      //   serif (Plex Serif)  headline, wordmark        — the warm, elegant note
      //   sans  (Plex Sans)   label, prose              — chrome + paragraphs
      //   mono  (Plex Mono)   reading, figure, display  — every figure, aligned
      // Serif and mono ship one weight each, so their fontWeight is nominal;
      // only Plex Sans has a real second weight (600).
      label: _sans.copyWith(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.3,
      ),
      reading: _mono.copyWith(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.4,
      ),
      figure: _mono.copyWith(
        color: ink,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.15,
      ),
      display: _mono.copyWith(
        color: ink,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        height: 1.1,
      ),
      // The warm voice. A high-contrast serif carries a two-line headline best
      // with tight leading and a hair of negative tracking.
      headline: _serif.copyWith(
        color: ink,
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.3,
        height: 1.15,
      ),
      prose: _sans.copyWith(
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.55,
      ),
      wordmark: _serif.copyWith(
        color: ink,
        fontSize: 46,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.05,
      ),
    );
  }

  @override
  JotaType copyWith({
    TextStyle? label,
    TextStyle? reading,
    TextStyle? figure,
    TextStyle? display,
    TextStyle? headline,
    TextStyle? prose,
    TextStyle? wordmark,
  }) {
    return JotaType(
      label: label ?? this.label,
      reading: reading ?? this.reading,
      figure: figure ?? this.figure,
      display: display ?? this.display,
      headline: headline ?? this.headline,
      prose: prose ?? this.prose,
      wordmark: wordmark ?? this.wordmark,
    );
  }

  @override
  JotaType lerp(ThemeExtension<JotaType>? other, double t) {
    if (other is! JotaType) return this;
    return JotaType(
      label: TextStyle.lerp(label, other.label, t)!,
      reading: TextStyle.lerp(reading, other.reading, t)!,
      figure: TextStyle.lerp(figure, other.figure, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      prose: TextStyle.lerp(prose, other.prose, t)!,
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
    );
  }
}

// ---- Theme assembly --------------------------------------------------------

abstract final class JotaTheme {
  static ThemeData light() => _build(JotaColors.light, Brightness.light);
  static ThemeData dark() => _build(JotaColors.dark, Brightness.dark);

  static ThemeData _build(JotaColors c, Brightness brightness) {
    final JotaType type = JotaType.of(c.ink);

    // Deliberately degenerate: primary, secondary and surface all resolve to
    // ink or paper. Any Material widget that reaches for a colour we did not
    // choose lands on monochrome rather than on Material 3 purple.
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.bg,
      secondary: c.ink,
      onSecondary: c.bg,
      error: c.signal,
      onError: c.bg,
      surface: c.bg,
      onSurface: c.ink,
      surfaceContainerHighest: c.field,
      outline: c.rule,
      outlineVariant: c.rule,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      // No shadows anywhere. The device is a flat 1-bit panel; a drop shadow
      // is the fastest way to make the app feel like a different product.
      shadowColor: Colors.transparent,
      dividerTheme: DividerThemeData(
        color: c.rule,
        thickness: JotaGrid.hairline,
        space: JotaGrid.hairline,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.selection,
        selectionHandleColor: c.ink,
      ),
      textTheme: TextTheme(
        displayLarge: type.display,
        headlineMedium: type.figure,
        titleMedium: type.label,
        bodyLarge: type.prose,
        bodyMedium: type.reading,
        labelLarge: type.label,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: type.label,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bg,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.rule),
          borderRadius: BorderRadius.zero,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: type.reading.copyWith(color: c.bg),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.field,
        hintStyle: type.reading.copyWith(color: c.inkMuted),
        labelStyle: type.label.copyWith(color: c.inkMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: JotaGrid.gapM,
          vertical: JotaGrid.gapM,
        ),
        border: OutlineInputBorder(
          borderRadius: JotaRows.borderRadiusOf(JotaRows.height),
          borderSide: BorderSide(color: c.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: JotaRows.borderRadiusOf(JotaRows.height),
          borderSide: BorderSide(color: c.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: JotaRows.borderRadiusOf(JotaRows.height),
          borderSide: BorderSide(color: c.ink),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: JotaRows.borderRadiusOf(JotaRows.height),
          borderSide: BorderSide(color: c.signal),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: JotaRows.borderRadiusOf(JotaRows.height),
          borderSide: BorderSide(color: c.signal),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[c, type],
    );
  }
}

// ---- Access ----------------------------------------------------------------
// `context.ink` / `context.type` rather than a Theme.of dance at every call
// site. Screens should read like the firmware's screens.cpp: a list of named
// tokens, not a pile of Theme lookups.
extension JotaThemeAccess on BuildContext {
  JotaColors get ink =>
      Theme.of(this).extension<JotaColors>() ?? JotaColors.light;

  JotaType get type =>
      Theme.of(this).extension<JotaType>() ?? JotaType.of(JotaColors.light.ink);
}
