// chat_list_screen.dart — lista de conversas (esqueleto HUD da Fase 1).
//
// Sem persistência ainda; dados são placeholders para validar o design.
// Fase 4 troca por stream do banco (drift + SQLCipher) via Riverpod.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/hud_tokens.dart';
import '../shell/widgets/hud_panel.dart';
import '../shell/widgets/neon_button.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (HudBreaks.isWide(MediaQuery.sizeOf(context).width)) {
      // Desktop: lista à esquerda, thread vazia à direita (master/detail).
      return Row(
        children: [
          const SizedBox(width: 380, child: _ChatList()),
          Expanded(
            child: Center(
              child: HudPanel(
                child: Text(
                  'Selecione uma conversa\n',
                  style: TextStyle(
                    fontFamily: HudFonts.title,
                    color: HudColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return const _ChatList();
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(HudSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'CONVERSAS',
                style: TextStyle(
                  fontFamily: HudFonts.title,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: HudColors.text,
                ),
              ),
              const Spacer(),
              HudShieldBadge(),
            ],
          ),
          const SizedBox(height: HudSpacing.m),
          const _PlaceholderThread(
            name: 'TÁTICO 001',
            preview: ['sem peer pareado', 'ICOMOS selo sempre ativo'],
            unread: false,
          ),
          const SizedBox(height: HudSpacing.s),
          const _PlaceholderThread(
            name: 'GRUPO 001 (EM BREVE)',
            preview: ['grupos entram na Fase 5', 'Sender Keys'],
            unread: false,
          ),
          const Spacer(),
          NeonButton(
            label: 'DIAGNÓSTICO DA ENGINE',
            variant: NeonVariant.ghost,
            icon: Icons.bolt_outlined,
            onPressed: () => context.push('/diagnostic'),
          ),
        ],
      ),
    );
  }
}

/// Selo "ICOMOS" — a segurança REAL do app (envelope). Selo "MARTELOS"
/// aparece só quando a camada opcional estiver ativa (Fase 5).
class HudShieldBadge extends StatelessWidget {
  const HudShieldBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HudSpacing.s,
        vertical: HudSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: HudColors.primary, width: 1),
        color: HudColors.primary.withValues(alpha: 0.08),
      ),
      child: Text(
        'ICOMOS',
        style: TextStyle(
          fontFamily: HudFonts.data,
          color: HudColors.primary,
          fontSize: 10,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _PlaceholderThread extends StatelessWidget {
  const _PlaceholderThread({
    required this.name,
    required this.preview,
    required this.unread,
  });

  final String name;
  final List<String> preview;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HudColors.secondary.withValues(alpha: 0.08),
              border: Border.all(color: HudColors.secondary, width: 1),
            ),
            child: Center(
              child: Text(
                name.substring(0, 1),
                style: TextStyle(
                  fontFamily: HudFonts.title,
                  color: HudColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: HudSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: HudFonts.title,
                    color: HudColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  preview.join(' · '),
                  style: TextStyle(
                    fontFamily: HudFonts.data,
                    fontSize: 11,
                    color: HudColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
