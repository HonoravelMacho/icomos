// settings_screen.dart — Configurações (esqueleto da Fase 1).
// Pânico L1–L3, licenças, reduzir-movimento e rede entram em fases seguintes.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/hud_tokens.dart';
import '../shell/widgets/hud_panel.dart';
import '../shell/widgets/neon_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(HudSpacing.m),
      children: [
        const HudPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONFIGURAÇÕES',
                style: TextStyle(
                  fontFamily: HudFonts.title,
                  fontSize: 17,
                  color: HudColors.text,
                ),
              ),
              SizedBox(height: HudSpacing.s),
              _Row('identidade sem conta', '✓ nunca haverá'),
              _Row('telemetria / analytics / crash reporting', '✓ nenhum'),
              _Row('idioma', 'pt-BR (default) + en'),
              _Row(
                'licenças',
                'MIT (app) · Apache-2.0 (Martelos) · LGPL (GMP)',
              ),
            ],
          ),
        ),
        const SizedBox(height: HudSpacing.m),
        HudPanel(
          bevel: HudBevel.large,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PÂNICO (Fase 6)',
                style: TextStyle(
                  fontFamily: HudFonts.title,
                  color: HudColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: HudSpacing.xs),
              Text(
                'L1 bloqueio · L2 destruição (crypto-shredding, padrão) · '
                'L3 coerção (cofre falso)',
                style: TextStyle(
                  fontFamily: HudFonts.data,
                  fontSize: 11,
                  color: HudColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HudSpacing.m),
        NeonButton(
          label: 'VER DIAGNÓSTICO DA ENGINE',
          variant: NeonVariant.ghost,
          icon: Icons.bolt_outlined,
          onPressed: () => context.push('/diagnostic'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              k,
              style: TextStyle(
                fontFamily: HudFonts.title,
                color: HudColors.text,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              v,
              style: TextStyle(
                fontFamily: HudFonts.data,
                fontSize: 12,
                color: HudColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
