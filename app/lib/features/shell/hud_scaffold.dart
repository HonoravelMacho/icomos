// hud_scaffold.dart — scaffold responsivo do HUD (rail ≥1024, senão bottom nav).
//
// ≥1024: rail vertical (master/detail pronto p/ desktop §11.3).
// 600–1024: NavigationBar compacta.
// <600: NavigationBar padrão.
import 'package:flutter/material.dart';

import '../../../core/theme/hud_tokens.dart';
import './widgets/status_orb.dart';

/// Destinos do shell; ordem é a ordem visual do rail/bottom.
enum HudDest { chat, vault, settings }

/// Estrutura do shell: corpo + destinos + status de conexão global.
class HudScaffold extends StatelessWidget {
  const HudScaffold({
    super.key,
    required this.dest,
    required this.onDest,
    required this.body,
    this.status = HudConnection.offline,
  });

  final HudDest dest;
  final ValueChanged<HudDest> onDest;
  final Widget body;
  final HudConnection status;

  static const _labels = {
    HudDest.chat: 'COMMS',
    HudDest.vault: 'COFRE',
    HudDest.settings: 'CONF',
  };

  static const _icons = {
    HudDest.chat: Icons.speaker_notes_outlined,
    HudDest.vault: Icons.shield_outlined,
    HudDest.settings: Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = HudBreaks.isWide(w);

    // Utilizando a proporção apenas como textura estática (grid). Sem blur.
    final bg = DecoratedBox(
      decoration: const BoxDecoration(color: HudColors.bg),
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );

    final title = Text(
      'ICOMOS',
      style: TextStyle(
        fontFamily: HudFonts.title,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 4,
        color: HudColors.primary,
      ),
    );

    final appBar = PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Container(
        color: HudColors.surface,
        padding: EdgeInsets.symmetric(horizontal: HudSpacing.l),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Row(
            children: [
              title,
              const Spacer(),
              StatusOrb(status: HudConnection.offline, showLabel: wide),
            ],
          ),
        ),
      ),
    );

    //no wide: rail fixo à esquerda (Selecao sim /.bottom mobile).
    final rail = NavigationRail(
      selectedIndex: dest.index,
      onDestinationSelected: (i) => onDest(HudDest.values[i]),
      labelType: NavigationRailLabelType.all,
      backgroundColor: HudColors.surface,
      indicatorColor: HudColors.primary.withValues(alpha: 0.18),
      selectedLabelTextStyle: TextStyle(
        fontFamily: HudFonts.title,
        color: HudColors.primary,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: HudFonts.title,
        color: HudColors.muted,
      ),
      destinations: [
        for (final d in HudDest.values)
          NavigationRailDestination(
            icon: Icon(_icons[d], size: 20),
            selectedIcon: Icon(_icons[d], size: 20),
            label: Text(_labels[d]!),
          ),
      ],
    );

    final scaffold = Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          Positioned.fill(child: bg), // grade é textura de fundo
          body, // conteúdo por cima
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 64,
              backgroundColor: HudColors.surface,
              indicatorColor: HudColors.primary.withValues(alpha: 0.18),
              selectedIndex: dest.index,
              onDestinationSelected: (i) => onDest(HudDest.values[i]),
              destinations: [
                for (final d in HudDest.values)
                  NavigationDestination(
                    icon: Icon(_icons[d], size: 22),
                    label: _labels[d]!,
                  ),
              ],
            ),
    );

    if (!wide) return scaffold;
    //no Desktop: rail + corpo lado-a-lado (master/detail futuro §11.3).
    return Row(
      children: [
        SizedBox(width: 96, child: rail),
        Expanded(child: scaffold),
      ],
    );
  }
}

/// Textura de grade fininha (rgba(0,229,255,.08)) — decoração 1-pixel, barata.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = HudColors.grid;
    const step = 32.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
