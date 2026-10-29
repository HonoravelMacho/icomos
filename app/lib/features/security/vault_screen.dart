// vault_screen.dart — Cofre de chaves (esqueleto da Fase 1).
// Realidade chegando: SQLCipher + Keystore/libsecret/DPAPI (Fase 2-3).
//
// Esta tela mostra, em linguagem simples, o que o Cofre FARÁ e o que já está.
import 'package:flutter/material.dart';

import '../../core/theme/hud_tokens.dart';
import '../shell/widgets/hud_panel.dart';
import '../shell/widgets/status_orb.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(HudSpacing.m),
      children: [
        HudPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COFRE DE CHAVES',
                style: TextStyle(
                  fontFamily: HudFonts.title,
                  fontSize: 17,
                  color: HudColors.text,
                ),
              ),
              const SizedBox(height: HudSpacing.xs),
              const StatusOrb(status: HudConnection.offline),
            ],
          ),
        ),
        const SizedBox(height: HudSpacing.m),
        const HudPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O que será guardado aqui',
                style: TextStyle(
                  fontFamily: HudFonts.title,
                  color: HudColors.text,
                ),
              ),
              SizedBox(height: HudSpacing.s),
              _Item('Identidade (Ed25519 + X25519) — Fase 3'),
              _Item('Chave do banco cifrado (SQLCipher) — Fase 2'),
              _Item('Chaves de sessão E2EE — Fase 2'),
              _Item('Botão de PÂNICO (L1 bloqueio, L2 destruição) — Fase 6'),
            ],
          ),
        ),
        const SizedBox(height: HudSpacing.s),
        HudPanel(
          borderColor: HudColors.alert,
          child: Text(
            'experimental, não auditado — o selo ICOMOS indica que o conteúdo '
            'cai no cofre; o selo MARTELOS (Fase 5) indica a camada extra '
            'opcional. Sem auditoria externa, sem cálculo formal.',
            style: TextStyle(
              fontFamily: HudFonts.data,
              fontSize: 11,
              color: HudColors.alert,
            ),
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.bolt_outlined, size: 14, color: HudColors.secondary),
          const SizedBox(width: HudSpacing.s),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: HudFonts.data,
                fontSize: 12,
                color: HudColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
