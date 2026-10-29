// app.dart — raiz do aplicativo ICOMOS.
//
// Fase 0: tela única de status (diagnóstico da engine nativa).
// Na Fase 1 entra o HUDScaffold + rota (go_router) com o design system.
import 'package:flutter/material.dart';

import 'core/ffi/engine_client.dart';
import 'screens/diagnostic_screen.dart';

class IcomosApp extends StatelessWidget {
  const IcomosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICOMOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const DiagnosticScreen(),
    );
  }
}

/// Placeholders para uso futuro (referências vivas, sem código morto).
// ignore: unused_element
final _ = EngineClient;
