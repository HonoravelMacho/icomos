// engine_client.dart — cliente de alto nível da engine nativa.
//
// FASE 0: executa no isolate da chamada; o `CryptoWorker` com isolate
// dedicado entra na Fase 2 junto do uso real de produção. A fila assíncrona
// (`_gate`) JÁ impede chamadas concorrentes ao motor — regra de безопасности
// "o motor MARTELOS não é reentrante" (docs/ADR/0001 e 0004).
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';

/// Resultado de uma operação de texto (cifrar/decifrar).
class EngineTextResult {
  EngineTextResult(this.bytes, {required this.houses});
  final Uint8List bytes;
  final List<int> houses;

  /// Conveniência em Utf-8 (apenas para texto).
  String get asText => utf8.decode(bytes);
}

/// Falha conhecida da engine — mensagem em pt-BR pronta para a UI.
class EngineException implements Exception {
  EngineException(this.code, this.message);
  final int code;
  final String message;

  @override
  String toString() => 'EngineException($code): $message';
}

/// Cliente da `libicomos_engine`.
class EngineClient {
  EngineClient._() {
    final eng = bindings().engineNew();
    if (eng == nullptr) {
      throw EngineException(0, 'Falha ao alocar contexto (icomos_new)');
    }
    _eng = eng;
    _abiVersion = bindings().abiVersion();
  }

  Pointer<Void> _eng = nullptr;
  late int _abiVersion;

  /// Fila FIFO: garante no máximo 1 chamada ao motor por vez.
  Future<void> _gate = Future.value();

  /// Instância única por isolate (isolates têm heaps separados por design).
  static final EngineClient instance = EngineClient._();

  int get abiVersion => _abiVersion;

  /// Enfileira uma operação para o motor. Uma falha não quebra a fila.
  Future<T> _run<T>(Future<T> Function() op) {
    final next = _gate.then((_) => op());
    _gate = next.then((_) {}, onError: (_) {});
    return next;
  }

  /// Cifra texto claro com N casas (1..8). Motor é lossy: vírgulas fora do
  /// alfabeto de 34 símbolos viram '-', acentos são removidos, MAIÚSCULAS
  /// forçadas (ver docs/PROTOCOL.md "Camada MARTELOS").
  Future<EngineTextResult> sealText(
    String plaintext, {
    required List<int> houses,
    required int constantIdx,
    String? formula,
  }) => _run(
    () => _runText(
      cipher: true,
      bytes: Uint8List.fromList(utf8.encode(plaintext)),
      casas: houses,
      constantIdx: constantIdx,
      formula: formula,
    ),
  );

  /// Decifra bytes de texto cifrado do motor (contrário de sealText).
  Future<EngineTextResult> openText(
    Uint8List ciphertext, {
    required List<int> houses,
    required int constantIdx,
    String? formula,
  }) => _run(
    () => _runText(
      cipher: false,
      bytes: ciphertext,
      casas: houses,
      constantIdx: constantIdx,
      formula: formula,
    ),
  );

  Future<EngineTextResult> _runText({
    required bool cipher,
    required Uint8List bytes,
    required List<int> casas,
    required int constantIdx,
    String? formula,
  }) async {
    final r = bindings().runText(
      _eng,
      seal: cipher,
      bytes: bytes,
      constantIdx: constantIdx,
      formula: formula,
      casas: casas,
    );
    if (r.rc != 0 || r.out == nullptr) {
      throw EngineException(r.rc, bindings().lastError(_eng));
    }
    if (r.outLen == 0) {
      bindings().bufFree(r.out);
      throw EngineException(r.rc, 'Saída vazia do motor');
    }
    final out = Uint8List.fromList(r.out.asTypedList(r.outLen));
    bindings().bufFree(r.out); // importante: SEMPRE liberar o buffer nativo
    return EngineTextResult(out, houses: casas);
  }
}
