// hud_golden_test.dart — goldens dos blocos de UI HUD (Fase 1).
//
// Fontes carregadas dos assets reais (FontLoader) para os goldens serem
// determinísticos em qualquer máquina. Para regenerar após uma mudança
// visual INTENCIONAL: `flutter test --update-goldens` (mudança vai no commit
// comentado, nunca automática).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:icomos/core/theme/hud_tokens.dart';
import 'package:icomos/features/shell/widgets/hud_panel.dart';
import 'package:icomos/features/shell/widgets/neon_button.dart';
import 'package:icomos/features/shell/widgets/status_orb.dart';

Future<void> _loadFonts() async {
  for (final f in const [
    ('Rajdhani', 'Rajdhani-Regular.ttf'),
    ('Rajdhani', 'Rajdhani-SemiBold.ttf'),
    ('Rajdhani', 'Rajdhani-Bold.ttf'),
    ('JetBrains Mono', 'JetBrainsMono-Variable.ttf'),
  ]) {
    final loader = FontLoader(f.$1)
      ..addFont(rootBundle.load('assets/fonts/${f.$2}'));
    await loader.load();
  }
}

/// Fundo sólido + centrado (goldens comparáveis = fundo determinístico).
Widget _surface(Widget child) => ColoredBox(
  color: HudColors.bg,
  child: Center(child: child),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('HudPanel renderiza chanfro + borda + conteúdo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: _surface(
          const HudPanel(
            child: SizedBox(
              width: 220,
              height: 60,
              child: Text(
                'PANEL TATICO',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: HudColors.text,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(HudPanel),
      matchesGoldenFile('goldens/hud_panel.png'),
    );
  });

  testWidgets('NeonButton: variantes visíveis', (tester) async {
    tester.view.physicalSize = const Size(400, 280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: _surface(
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NeonButton(label: 'LIGAR PEER', onPressed: () {}),
                const SizedBox(height: 8),
                NeonButton(
                  label: 'IMPORTAR',
                  variant: NeonVariant.ghost,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                NeonButton(
                  label: 'PANIC',
                  variant: NeonVariant.danger,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                NeonButton(label: 'DESLIGADO', onPressed: null),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/neon_buttons.png'),
    );
  });

  testWidgets('StatusOrb: 4 estados em linha', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // desliga animações nos testes — determinismo no golden.
          data: const MediaQueryData(disableAnimations: true),
          child: _surface(
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusOrb(status: HudConnection.online),
                SizedBox(height: 8),
                StatusOrb(status: HudConnection.mesh),
                SizedBox(height: 8),
                StatusOrb(status: HudConnection.offline),
                SizedBox(height: 8),
                StatusOrb(status: HudConnection.waitingPeer),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/status_orbs.png'),
    );
    // descarrega a árvore — o dispose do StatusOrb cancela o timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
