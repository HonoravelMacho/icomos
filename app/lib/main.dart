// main.dart — ponto de entrada do ICOMOS.
//
// Fase 1: tema HUD + shell responsivo (go_router) + telas esqueleto +
// diagnóstico da engine (Fase 0). Riverpod entra na Fase 2 com o estado real.
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IcomosApp());
}
