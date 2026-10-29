// diagnostic_screen.dart — tela de diagnóstico da Fase 0 (HUD mínimo).
//
// Mostra: ABI da engine, roundtrip π, e status "experimental, não auditado".
// Será substituída pelo shell HUD completo na Fase 1.
import 'package:flutter/material.dart';

import '../core/ffi/engine_client.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String _status = 'carregando engine nativa...';

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  Future<void> _runDiagnostic() async {
    try {
      final client = EngineClient.instance;
      const msg = 'TESTE ICOMOS 0312';
      final ct = await client.sealText(
        msg,
        houses: const [424242, 777, 8080],
        constantIdx: /* pi */ 1,
      );
      final pt = await client.openText(
        ct.bytes,
        houses: const [424242, 777, 8080],
        constantIdx: 1,
      );
      final ok = pt.asText == msg;
      setState(
        () => _status = ok
            ? 'OK · ABI v${client.abiVersion} · roundtrip π/casas OK\n'
                  'cifrado: ${String.fromCharCodes(ct.bytes.take(40))}'
            : 'FALHA no roundtrip — ver log',
      );
    } catch (e) {
      setState(() => _status = 'ERRO: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ICOMOS',
              style: TextStyle(
                color: Color(0xFF00FFAA),
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'experimental, não auditado',
              style: TextStyle(color: Color(0xFF7A8B96)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D141A),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1),
              ),
              child: Text(
                _status,
                style: const TextStyle(
                  color: Color(0xFFD7E6EE),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
