// app_router.dart — rotas do ICOMOS (go_router, BSD-3; decisão ADR pendente).
//
// Fase 1: shell + 3 telas esqueleto + rota de diagnóstico (herança da Fase 0).
// go_router escolhido por ser o padrão do Flutter (docs) e pequeno: permite
// deep-links futuros ex.: janelas múltiplas no desktop, sem custo agora.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_list_screen.dart';
import '../features/security/vault_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/hud_scaffold.dart';
import '../screens/diagnostic_screen.dart';

DiagnosticScreen? _mountedDiagnostic; // 1 instância só (Fase 0, simples).

final goRouter = GoRouter(
  routes: <RouteBase>[
    ShellRoute(
      builder: (context, state, child) => _ShellHost(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ChatListScreen()),
        GoRoute(path: '/vault', builder: (_, _) => const VaultScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
    GoRoute(
      path: '/diagnostic',
      builder: (_, _) {
        // 1 instância somente para preservar estado do diagnóstica na nav,
        // (isolates não propagam EngineClient — aqui uso 1 singleton).
        return _mountedDiagnostic ??= const DiagnosticScreen();
      },
    ),
  ],
);

/// Host do shell: reconstrói o HudScaffold conforme a rota ativa.
class _ShellHost extends StatelessWidget {
  const _ShellHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final dest = switch (location) {
      '/vault' => HudDest.vault,
      '/settings' => HudDest.settings,
      _ => HudDest.chat,
    };
    return HudScaffold(
      dest: dest,
      onDest: (d) => context.go(switch (d) {
        HudDest.chat => '/',
        HudDest.vault => '/vault',
        HudDest.settings => '/settings',
      }),
      body: child,
    );
  }
}
