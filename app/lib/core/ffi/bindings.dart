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

// --- Fase 2: assinaturas das funções de cripto/KDF ---
typedef NativeIntFn = Int32 Function();
typedef DartIntFn = int Function();

typedef NativeRandom = Int32 Function(Pointer<Uint8>, Size);
typedef DartRandom = int Function(Pointer<Uint8>, int);

typedef NativeBlake2b =
    Int32 Function(Pointer<Uint8>, Size, Pointer<Uint8>, Size);
typedef DartBlake2b = int Function(Pointer<Uint8>, int, Pointer<Uint8>, int);

typedef NativeDeriveKeys =
    Int32 Function(
      Pointer<Uint8>,
      Size,
      Pointer<Uint8>,
      Size,
      Int32,
      Pointer<Uint64>,
      Pointer<Int32>,
    );
typedef DartDeriveKeys =
    int Function(
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      int,
      Pointer<Uint64>,
      Pointer<Int32>,
    );

typedef NativePair32x = Int32 Function(Pointer<Uint8>, Pointer<Uint8>);
typedef DartPair32x = int Function(Pointer<Uint8>, Pointer<Uint8>);

typedef NativeEdAction =
    Int32 Function(Pointer<Uint8>, Size, Pointer<Uint8>, Pointer<Uint8>);
typedef DartEdAction =
    int Function(Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Uint8>);

typedef NativeEd2X = Int32 Function(Pointer<Uint8>, Pointer<Uint8>);
typedef DartEd2X = int Function(Pointer<Uint8>, Pointer<Uint8>);

typedef NativeScalar =
    Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>);
typedef DartScalar =
    int Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>);

typedef NativeAead =
    Int32 Function(
      Pointer<Uint8>,
      Size,
      Pointer<Uint8>,
      Pointer<Uint8>,
      Pointer<Uint8>,
      Pointer<Size>,
    );
typedef DartAead =
    int Function(
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      Pointer<Uint8>,
      Pointer<Uint8>,
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

    // --- Fase 2: criptografia + KDF (typedefs no topo do arquivo) ---
    _sodiumInit = dylib.lookupFunction<NativeIntFn, DartIntFn>(
      'icomos_sodium_init',
    );
    _random = dylib.lookupFunction<NativeRandom, DartRandom>('icomos_random');
    _blake2b = dylib.lookupFunction<NativeBlake2b, DartBlake2b>(
      'icomos_blake2b',
    );

    _deriveKeys = dylib.lookupFunction<NativeDeriveKeys, DartDeriveKeys>(
      'icomos_derive_keys',
    );

    _edKeyPair = dylib.lookupFunction<NativePair32x, DartPair32x>(
      'icomos_ed25519_keypair',
    );
    _xKeyPair = dylib.lookupFunction<NativePair32x, DartPair32x>(
      'icomos_x25519_keypair',
    );

    _edSign = dylib.lookupFunction<NativeEdAction, DartEdAction>(
      'icomos_ed25519_sign',
    );
    _edVerify = dylib.lookupFunction<NativeEdAction, DartEdAction>(
      'icomos_ed25519_verify',
    );

    _edToX = dylib.lookupFunction<NativeEd2X, DartEd2X>(
      'icomos_ed25519_pk_to_x25519',
    );
    _xScalar = dylib.lookupFunction<NativeScalar, DartScalar>(
      'icomos_x25519_scalarmult',
    );

    _aeadSeal = dylib.lookupFunction<NativeAead, DartAead>('icomos_aead_seal');
    _aeadOpen = dylib.lookupFunction<NativeAead, DartAead>('icomos_aead_open');
  }

  late final int Function() _abi;
  late final Pointer<Void> Function() _new;
  late final void Function(Pointer<Void>) _free;
  late final Pointer<Utf8> Function(Pointer<Void>) _lastError;
  late final NativeSealTextDart _sealText;
  late final NativeSealTextDart _openText;
  late final void Function(Pointer<Void>) _bufFree;
  // --- Fase 2 ---
  late final int Function() _sodiumInit;
  late final int Function(Pointer<Uint8>, int) _random;
  late final int Function(Pointer<Uint8>, int, Pointer<Uint8>, int) _blake2b;
  late final DartDeriveKeys _deriveKeys;
  late final DartPair32x _edKeyPair;
  late final DartPair32x _xKeyPair;
  late final DartEdAction _edSign;
  late final DartEdAction _edVerify;
  late final DartEd2X _edToX;
  late final DartScalar _xScalar;
  late final DartAead _aeadSeal;
  late final DartAead _aeadOpen;

  int abiVersion() => _abi();
  Pointer<Void> engineNew() => _new();
  void engineFree(Pointer<Void> eng) => _free(eng);
  String lastError(Pointer<Void> eng) => _lastError(eng).toDartString();
  void bufFree(Pointer<Uint8> p) => _bufFree(p.cast<Void>());

  /// sodium_init idempotente.
  int sodiumInit() => _sodiumInit();

  /// Aleatório criptográfico do SO (único caminho legítmo).
  int randomFill(Pointer<Uint8> buf, int n) => _random(buf, n);

  /// BLAKE2b genérico. Retorna 0 quando ok.
  int blake2b(
    Pointer<Uint8> input,
    int inLen,
    Pointer<Uint8> out,
    int outLen,
  ) => _blake2b(input, inLen, out, outLen);

  /// Argon2id + HKDF → N casas + constante. Ok = 0.
  int deriveKeys(
    Pointer<Uint8> secret,
    int secretLen,
    Pointer<Uint8> salt,
    int saltLen,
    int layers,
    Pointer<Uint64> casas,
    Pointer<Int32> constant,
  ) => _deriveKeys(secret, secretLen, salt, saltLen, layers, casas, constant);

  /// Ed25519: gera keypair. Ok = 0.
  int edKeyPair(Pointer<Uint8> pub, Pointer<Uint8> priv) =>
      _edKeyPair(pub, priv);

  /// Ed25519: sign. Ok = 0.
  int edSign(
    Pointer<Uint8> msg,
    int len,
    Pointer<Uint8> priv,
    Pointer<Uint8> sig,
  ) => _edSign(msg, len, priv, sig);

  /// Ed25519: verify. 0 = válido; -1 = inválido (libsodium).
  int edVerify(
    Pointer<Uint8> msg,
    int len,
    Pointer<Uint8> pub,
    Pointer<Uint8> sig,
  ) => _edVerify(msg, len, pub, sig);

  /// Converte pub Ed25519 → X25519. Ok = 0.
  int edToX(Pointer<Uint8> edPub, Pointer<Uint8> xPub) => _edToX(edPub, xPub);

  /// X25519 keypair. Ok = 0.
  int xKeyPair(Pointer<Uint8> pub, Pointer<Uint8> priv) => _xKeyPair(pub, priv);

  /// X25519 scalarmult (acordo efêmero). Ok = 0.
  int xScalar(
    Pointer<Uint8> myPriv,
    Pointer<Uint8> peerPub,
    Pointer<Uint8> shared,
  ) => _xScalar(myPriv, peerPub, shared);

  /// AEAD seal: out = ct+16 (mac). Ok = 0.
  int aeadSeal(
    Pointer<Uint8> input,
    int len,
    Pointer<Uint8> nonce,
    Pointer<Uint8> key,
    Pointer<Uint8> out,
    Pointer<Size> outLen,
  ) => _aeadSeal(input, len, nonce, key, out, outLen);

  /// AEAD open: out_len sem mac. Rejeita em -1 (mac inválida). Ok = 0.
  int aeadOpen(
    Pointer<Uint8> input,
    int len,
    Pointer<Uint8> nonce,
    Pointer<Uint8> key,
    Pointer<Uint8> out,
    Pointer<Size> outLen,
  ) => _aeadOpen(input, len, nonce, key, out, outLen);

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
