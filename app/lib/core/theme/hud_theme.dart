// hud_theme.dart — ThemeData material derivado dos tokens HUD.
//
// Material mantém acessibilidade, SelectionArea, TalkBack etc; a cara HUD
// vem dos widgets chanfrados (HudPanel, NeonButton) por cima deste tema.
import 'package:flutter/material.dart';

import 'hud_tokens.dart';

ThemeData hudTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: HudColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: HudColors.primary,
      secondary: HudColors.secondary,
      surface: HudColors.panel,
      onPrimary: HudColors.bg,
      onSecondary: HudColors.bg,
      onSurface: HudColors.text,
      error: HudColors.danger,
    ),
    textTheme: _textTheme(base.textTheme),
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    iconTheme: const IconThemeData(color: HudColors.primary, size: 22),
    dividerTheme: const DividerThemeData(
      color: HudColors.grid,
      thickness: 1,
      space: 1,
    ),
  );
}

/// Título em Rajdhani (com peso forte), dados em JetBrains Mono.
TextTheme _textTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontFamily: HudFonts.title,
      color: HudColors.primary,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: HudFonts.title,
      color: HudColors.text,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontFamily: HudFonts.title,
      color: HudColors.text,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontFamily: HudFonts.title,
      color: HudColors.muted,
    ),
    bodyMedium: base.bodyMedium?.copyWith(color: HudColors.text, fontSize: 15),
    bodySmall: base.bodySmall?.copyWith(color: HudColors.muted),
    labelLarge: base.labelLarge?.copyWith(fontFamily: HudFonts.title),
  );
}
