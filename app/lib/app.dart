// app.dart — raiz do aplicativo ICOMOS (Fase 1: tema HUD + shell HUD).
import 'package:flutter/material.dart';

import 'core/theme/hud_theme.dart';
import 'routing/app_router.dart';

class IcomosApp extends StatelessWidget {
  const IcomosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ICOMOS',
      debugShowCheckedModeBanner: false,
      theme: hudTheme(),
      routerConfig: goRouter,
    );
  }
}
