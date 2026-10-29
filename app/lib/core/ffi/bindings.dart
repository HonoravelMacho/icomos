// bindings.dart — Bindings FFI diretos da C ABI `libicomos_engine`.
//
// Camada 1 de 2: "raw" (sem lógica de protocolo). `engine_client.dart` é a
// camada de uso (isolate único + fila). A fonte da verdade da ABI é o header
// native/icomos_engine/include/icomos_engine.h.
//
// Regras de segurança guardadas aqui:
//  - Um ÚNICO contexto `icomos_engine` por processo, usado por um único
//    isolate (CryptoWorker) — o motor MARTELOS não é reentrante (motor.c:3-6).
//  - Todo buffer de saída do motor é liberado por `buf_free`.
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Exceção de carregamento da engine nativa, com as tentativas feitas.
class EngineLoadException implements Exception {
  EngineLoadException(this.attempts);
  final List<String> attempts;

  @override
  String toString() =>
      'IcomosEngine não carregada. Tentativas:\n${attempts.join('\n')}';
}

/// Localiza e abre a biblioteca nativa.
/// Ordem de busca (primeira que funciona vence):
///   1. env ICOMOS_ENGINE_LIB (usado pelo CI),
///   2. name padrão (junto ao executável / bundle),
///   3. build nativo relativo (dev: `flutter test` roda dentro de app/),
///   4. app/linux/lib (saída de native/scripts/build_linux.sh).
DynamicLibrary loadIcomosEngine() {
  final attempts = <String>[];
  final env = Platform.environment['ICOMOS_ENGINE_LIB'];
  final candidates = <String, String>{
    ?env: 'env ICOMOS_ENGINE_LIB', // env pode estar ausente (map null-aware)
    'libicomos_engine.so': 'resolvido no loader',
    '../native/icomos_engine/build-linux/libicomos_engine.so':
        'build relativo (flutter test em app/)',
    'native/icomos_engine/build-linux/libicomos_engine.so':
        'build relativo (raiz do repo)',
    'linux/lib/libicomos_engine.so': 'bundle app',
  };
  for (final entry in candidates.entries) {
    try {
      final dl = DynamicLibrary.open(entry.key);
      return dl;
    } catch (e) {
      attempts.add('${entry.value} [$entry.key]: $e');
    }
  }
  throw EngineLoadException(attempts);
}

/// Índices de constante do motor (motor.c:83-96 obter_esteira_numerica).
abstract final class MartelosConstant {
  static const int pi = 1;
  static const int formulaCustom = 2;
  static const int catalan = 3;
  static const int apery = 4;
  static const int clausen = 5;
  static const int arctan = 6;
  static const int log3 = 7;
}

/// Assinatura compartilhada de seal/open de texto (idênticas na ABI).
typedef NativeSealTextNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      Size,
      Int32,
      Pointer<Utf8>,
      Pointer<Uint64>,
      Int32,
      Pointer<Pointer<Uint8>>,
      Pointer<Size>,
    );
typedef NativeSealTextDart =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      int,
      Pointer<Utf8>,
      Pointer<Uint64>,
      int,
      Pointer<Pointer<Uint8>>,
      Pointer<Size>,
    );

/// Bindings de baixo nível da `libicomos_engine`.
class IcomosEngineBindings {
  IcomosEngineBindings._(DynamicLibrary dylib) {
    _abi = dylib.lookupFunction<Int32 Function(), int Function()>(
      'icomos_abi_version',
    );
    _new = dylib
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'icomos_new',
        );
    _free = dylib
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('icomos_free');
    _lastError = dylib
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Void>),
          Pointer<Utf8> Function(Pointer<Void>)
        >('icomos_last_error');

    _sealText = dylib.lookupFunction<NativeSealTextNative, NativeSealTextDart>(
      'icomos_seal_text',
    );
    _openText = dylib.lookupFunction<NativeSealTextNative, NativeSealTextDart>(
      'icomos_open_text',
    );

    _bufFree = dylib
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('icomos_buf_free');
  }

  late final int Function() _abi;
  late final Pointer<Void> Function() _new;
  late final void Function(Pointer<Void>) _free;
  late final Pointer<Utf8> Function(Pointer<Void>) _lastError;
  late final NativeSealTextDart _sealText;
  late final NativeSealTextDart _openText;
  late final void Function(Pointer<Void>) _bufFree;

  int abiVersion() => _abi();
  Pointer<Void> engineNew() => _new();
  void engineFree(Pointer<Void> eng) => _free(eng);
  String lastError(Pointer<Void> eng) => _lastError(eng).toDartString();
  void bufFree(Pointer<Uint8> p) => _bufFree(p.cast<Void>());

  /// Executa seal/open de texto. Retorna (código, ponteiro de saída, tamanho).
  /// O chamador é dono do ponteiro de saída e DEVE liberar via bufFree.
  ({int rc, Pointer<Uint8> out, int outLen}) runText(
    Pointer<Void> eng, {
    required bool seal,
    required Uint8List bytes,
    required int constantIdx,
    String? formula,
    required List<int> casas,
  }) {
    // Entrada: os motor espera C-string NUL-terminada; copiamos com +1.
    final inBuf = calloc<Uint8>(bytes.length + 1);
    inBuf.asTypedList(bytes.length).setAll(0, bytes);
    inBuf[bytes.length] = 0;

    final outPtr = calloc<Pointer<Uint8>>();
    final outLen = calloc<Size>();
    final casasBuf = calloc<Uint64>(casas.length);
    casasBuf.asTypedList(casas.length).setAll(0, casas);

    final formulaPtr = (formula == null || formula.isEmpty)
        ? nullptr.cast<Utf8>()
        : formula.toNativeUtf8();

    final fn = seal ? _sealText : _openText;
    final rc = fn(
      eng,
      inBuf,
      bytes.length,
      constantIdx,
      formulaPtr.cast<Utf8>(),
      casasBuf,
      casas.length,
      outPtr,
      outLen,
    );

    calloc.free(inBuf);
    calloc.free(casasBuf);
    if (formulaPtr != nullptr) calloc.free(formulaPtr);
    final result = (rc: rc, out: outPtr.value, outLen: outLen.value);
    calloc.free(outPtr);
    calloc.free(outLen);
    return result;
  }
}

/// Singleton de bindings: abre a lib exatamente 1x por processo.
/// (O CryptoWorker chamando este arquivo em outro isolate cria a instância
/// do isolate — isolates não compartilham heap, o que só ajuda na regra
/// "uma chamada ao motor por vez".)
IcomosEngineBindings bindings() {
  _cached ??= IcomosEngineBindings._(loadIcomosEngine());
  return _cached!;
}

IcomosEngineBindings? _cached;
