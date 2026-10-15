import 'package:flutter/material.dart';

/// Tutoria's design tokens: colours, type, radii, spacing and shadows.
///
/// The palette comes from the approved screen designs (sampled from the mockup board), with
/// the logo's gold kept as the star accent. Use these names — not raw hex values — in screens,
/// so the whole app can be re-skinned from this one file. docs/DESIGN_SYSTEM.md lists them.
class TColors {
  TColors._();

  // --- Brand blue
  static const blue800 = Color(0xFF0245B0); // gradient end, pressed states
  static const blue700 = Color(0xFF0253D5); // splash / header gradient start
  static const blue600 = Color(
    0xFF0561E6,
  ); // primary: buttons, headers, links, user chat bubbles
  static const blue500 = Color(
    0xFF0A7AF5,
  ); // bright accent: highlights, focus rings
  static const blue200 = Color(
    0xFFB8D8FF,
  ); // borders on blue tints, progress track
  static const blue100 = Color(
    0xFFE2F1FE,
  ); // tutor chat bubble, selected rows, chips
  static const blue50 = Color(0xFFF3F8FF); // page background

  // --- Sunshine yellow: the call-to-action colour, plus the logo's gold star
  static const yellow = Color(0xFFFEE517); // primary CTA on blue
  static const yellowDeep = Color(0xFFFFC21A); // pressed state, borders
  static const yellowTint = Color(
    0xFFFEF5D2,
  ); // "I'm a Parent" card, highlights
  static const gold = Color(0xFFFEBF00); // the logo's star

  // --- Ink: text
  static const ink = Color(
    0xFF08185B,
  ); // headings (deep navy, as in the dashboard design)
  static const body = Color(0xFF2B3A67); // body text
  static const muted = Color(0xFF61759F); // secondary text, hints
  static const faint = Color(0xFF9AA7CC); // placeholders, disabled

  // --- Surfaces and lines
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0xFFDCE8F8); // card and field borders
  static const fieldFill = Color(0xFFFFFFFF);

  // --- Feedback
  static const success = Color(0xFF1BB464);
  static const warning = Color(0xFFFC7B0A);
  static const danger = Color(0xFFE5484D);
  static const dangerTint = Color(0xFFFDECEC);

  // --- Subject accents: a solid colour for icon badges, a pastel tint for the card behind it
  static const mathsAccent = blue600;
  static const mathsTint = Color(0xFFDBEFFF);
  static const englishAccent = Color(0xFFFF4B7D);
  static const englishTint = Color(0xFFFFE5EF);
  static const scienceAccent = Color(0xFF12B886);
  static const scienceTint = Color(0xFFD4F7EE);
  static const worldAccent = Color(0xFF0EA5B7);
  static const worldTint = Color(0xFFD3F3F6);
  static const socialAccent = Color(0xFFFC7B0A);
  static const socialTint = Color(0xFFFFEAD7);
  static const computingAccent = Color(0xFF8B4DE8);
  static const computingTint = Color(0xFFEFE1FF);

  /// Page background: white fading to a pale sky blue, as in the dashboard design.
  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, Color(0xFFF0F8FF)],
  );

  /// The "Continue learning" card.
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0072FF), Color(0xFF0665E9)],
  );

  /// Hero gradient: splash screen and the home header.
  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [blue600, blue700],
  );
}

/// Corner radii. Cards are generous and friendly; fields and buttons slightly tighter.
class TRadius {
  TRadius._();
  static const sm = 10.0;
  static const md = 14.0; // fields, buttons
  static const lg = 20.0; // cards
  static const xl = 28.0; // sheets, hero panels
  static const pill = 999.0;
}

/// 4-pt spacing scale.
class TSpace {
  TSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Side padding of every screen.
  static const page = 20.0;
}

class TShadows {
  TShadows._();

  /// A soft, blue-tinted lift for cards and the nav bar.
  static const card = [
    BoxShadow(color: Color(0x140245B0), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x290245B0), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

/// Typography: Nunito (bundled, SIL Open Font Licence), rounded and friendly like the mockups.
/// The font is variable, so each style sets the weight axis explicitly as well as fontWeight.
class TText {
  TText._();

  static const family = 'Nunito';

  static TextStyle _s(
    double size,
    double weight,
    Color color, {
    double? height,
    double? spacing,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: [FontVariation('wght', weight)],
      color: color,
      height: height,
      letterSpacing: spacing,
    );
  }

  static FontWeight _weight(double w) =>
      FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

  static final display = _s(
    34,
    900,
    TColors.ink,
    height: 1.1,
  ); // splash headline
  static final title = _s(26, 800, TColors.ink, height: 1.15); // screen titles
  static final heading = _s(
    20,
    800,
    TColors.ink,
    height: 1.2,
  ); // section titles
  static final subheading = _s(17, 700, TColors.ink, height: 1.25);
  static final body = _s(15, 500, TColors.body, height: 1.4);
  static final bodyBold = _s(15, 700, TColors.body, height: 1.4);
  static final small = _s(13, 500, TColors.muted, height: 1.35);
  static final smallBold = _s(13, 700, TColors.muted, height: 1.35);
  static final caption = _s(11.5, 600, TColors.muted, height: 1.3);
  static final button = _s(16, 800, TColors.white, spacing: 0.2);
  static final label = _s(13, 700, TColors.ink); // field labels
}
