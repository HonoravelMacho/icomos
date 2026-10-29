// hud_tokens.dart — Tokens de design do HUD tático (fonte única de verdade).
//
// Consumidos por hud_theme.dart e pelos widgets de features/. NENHUM widget
// deve usar cor/medida mágica fora daqui (regra de design, ADR a criar na
// primeira auditoria visual).
import 'package:flutter/material.dart';

/// Cores oficiais do HUD ( espaçamento em px lógicos ).
abstract final class HudColors {
  static const Color bg = Color(0xFF05070A);
  static const Color surface = Color(0xFF0A0F14);
  static const Color panel = Color(0xFF0D141A);
  static const Color primary = Color(0xFF00FFAA);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color alert = Color(0xFFFFB000);
  static const Color danger = Color(0xFFFF3B5C);
  static const Color text = Color(0xFFD7E6EE);
  static const Color muted = Color(0xFF7A8B96);
  static const Color grid = Color(0x1400E5FF); // rgba(0,229,255,.08)
}

/// Espaçamento em múltiplos de 4.
abstract final class HudSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Chanfros (cantos cortados — o "bevel" do HUD).
abstract final class HudBevel {
  static const double small = 10;
  static const double large = 14;
}

/// Durações de motion — respeitar reduce_motion no consumer (MotionGuard).
abstract final class HudMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);

  /// Curva padrão das transições do HUD.
  static const Curve curve = Cubic(0.22, 1, 0.36, 1); // easeOutCubic-like

  /// Curva para quando o usuário pediu "reduzir movimento" (acessibilidade).
  static const Curve reducedCurve = Curves.linear;
}

/// Familias de fonte declaradas no pubspec (assets/fonts).
abstract final class HudFonts {
  static const String title = 'Rajdhani'; // títulos e rótulos
  static const String data = 'JetBrains Mono'; // dados, IDs, cifras
}

/// Breakpoints responsivos (§11.3 do produto).
abstract final class HudBreaks {
  static const double compact = 600; // < 600 → mobile
  static const double medium = 1024; // 600–1024 → tablet; > 1024 → desktop

  static bool isCompact(double w) => w < compact;
  static bool isMedium(double w) => w >= compact && w <= medium;
  static bool isWide(double w) => w > medium;
}

/// Glow padrão do HUD — implementado por BoxShadow/BoxDecoration onde couber,
/// e por widget dedicado (Vignette/GlowLine) se precisar de canvas.
class HudGlow {
  static List<BoxShadow> of(Color color, {double blur = 12}) => [
    BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: blur),
    BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: blur * 2),
  ];
}

/// Estados de conexão mostrados por StatusOrb (transporte/ICOMOS).
enum HudConnection { online, offline, mesh, waitingPeer }

extension HudConnectionX on HudConnection {
  Color get color => switch (this) {
    HudConnection.online => HudColors.primary,
    HudConnection.mesh => HudColors.secondary,
    HudConnection.offline => HudColors.muted,
    HudConnection.waitingPeer => HudColors.alert,
  };
  String get label => switch (this) {
    HudConnection.online => 'ONLINE',
    HudConnection.mesh => 'MESH',
    HudConnection.offline => 'OFFLINE',
    HudConnection.waitingPeer => 'AGUARDANDO PEER',
  };
}
