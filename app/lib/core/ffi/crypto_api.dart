// crypto_api.dart — API Dart de alto nível sobre as funções de cripto da
// `libicomos_engine` (libsodium). Sem lógica de protocolo aqui: byte in →
// byte out. O protocolo (envelope/playoad) vive em core/crypto/.
//
// ICOMOS usable MIT; libsodium é MIT; tudo "experimental, não auditado".
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

/// Tamanhos fixos (espelham icomos_engine.h).
abstract final class CryptoSizes {
  static const int ed25519Pub = 32;
  static const int ed25519Priv = 64;
  static const int ed25519Sig = 64;
  static const int x25519Pub = 32;
  static const int x25519Priv = 32;
  static const int x25519Shared = 32;
  static const int aeadNonce = 24;
  static const int aeadKey = 32;
  static const int aeadMac = 16;
  static const int kdfSalt = 16;
  static const int kdfOut = 32;
}

/// Falha da cripto (mensagem pronta para a UI, pt-BR).
class CryptoFailure implements Exception {
  CryptoFailure(this.message);
  final String message;
  @override
  String toString() => 'CryptoFailure: $message';
}

/// Camada fina: cada método assume inputs válidos e valida tamanho.
class CryptoApi {
  CryptoApi._();
  static final CryptoApi instance = CryptoApi._();

  IcomosEngineBindings _b() => bindings();

  void sodiumInit() {
    _b().sodiumInit();
  }

  /// Aleatório criptográfico (única fonte permitida).
  Uint8List randomBytes(int n) {
    final p = calloc<Uint8>(n);
    final rc = _b().randomFill(p, n);
    if (rc != 0) {
      calloc.free(p);
      throw CryptoFailure('falha no gerador de aleatório (rc=$rc)');
    }
    final out = Uint8List.fromList(p.asTypedList(n));
    calloc.free(p);
    return out;
  }

  /// BLAKE2b de `data` com tamanho ajustável (1..64).
  Uint8List blake2b(Uint8List data, {int outLen = 32}) {
    final inp = calloc<Uint8>(data.length);
    inp.asTypedList(data.length).setAll(0, data);
    final out = calloc<Uint8>(outLen);
    final rc = _b().blake2b(inp, data.length, out, outLen);
    calloc.free(inp);
    if (rc != 0) {
      calloc.free(out);
      throw CryptoFailure('blake2b falhou (rc=$rc)');
    }
    final o = Uint8List.fromList(out.asTypedList(outLen));
    calloc.free(out);
    return o;
  }

  /// Par Ed25519 (pub 32, priv 64).
  ({Uint8List pub, Uint8List priv}) ed25519Keypair() {
    final pub = calloc<Uint8>(CryptoSizes.ed25519Pub);
    final priv = calloc<Uint8>(CryptoSizes.ed25519Priv);
    _b().edKeyPair(pub, priv);
    final p = Uint8List.fromList(pub.asTypedList(CryptoSizes.ed25519Pub));
    final s = Uint8List.fromList(priv.asTypedList(CryptoSizes.ed25519Priv));
    calloc
      ..free(pub)
      ..free(priv);
    return (pub: p, priv: s);
  }

  /// Assina `msg` com Ed25519 → 64 B.
  Uint8List ed25519Sign(Uint8List msg, Uint8List priv) {
    assert(priv.length == CryptoSizes.ed25519Priv);
    final mp = calloc<Uint8>(msg.length);
    mp.asTypedList(msg.length).setAll(0, msg);
    final sp = calloc<Uint8>(priv.length);
    sp.asTypedList(priv.length).setAll(0, priv);
    final sig = calloc<Uint8>(CryptoSizes.ed25519Sig);
    final rc = _b().edSign(mp, msg.length, sp, sig);
    calloc
      ..free(mp)
      ..free(sp);
    if (rc != 0) {
      calloc.free(sig);
      throw CryptoFailure('assinatura falhou (rc=$rc)');
    }
    final s = Uint8List.fromList(sig.asTypedList(CryptoSizes.ed25519Sig));
    calloc.free(sig);
    return s;
  }

  /// Verifica assinatura Ed25519. `true` somente se autêntica.
  bool ed25519Verify(Uint8List msg, Uint8List pub, Uint8List sig) {
    if (sig.length != CryptoSizes.ed25519Sig ||
        pub.length != CryptoSizes.ed25519Pub) {
      return false; // tamanho inválido = rejeição, não exceção
    }
    final mp = calloc<Uint8>(msg.length);
    mp.asTypedList(msg.length).setAll(0, msg);
    final pp = calloc<Uint8>(pub.length);
    pp.asTypedList(pub.length).setAll(0, pub);
    final sp = calloc<Uint8>(sig.length);
    sp.asTypedList(sig.length).setAll(0, sig);
    final rc = _b().edVerify(mp, msg.length, pp, sp);
    calloc
      ..free(mp)
      ..free(pp)
      ..free(sp);
    return rc == 0;
  }

  /// Converte pub Ed25519 → X25519 (mesma identidade, curvas irmãs).
  Uint8List ed25519PubToX25519(Uint8List edPub) {
    final ep = calloc<Uint8>(edPub.length);
    ep.asTypedList(edPub.length).setAll(0, edPub);
    final xp = calloc<Uint8>(CryptoSizes.x25519Pub);
    final rc = _b().edToX(ep, xp);
    calloc.free(ep);
    if (rc != 0) {
      calloc.free(xp);
      throw CryptoFailure('conversão Ed25519→X25519 falhou (rc=$rc)');
    }
    final o = Uint8List.fromList(xp.asTypedList(CryptoSizes.x25519Pub));
    calloc.free(xp);
    return o;
  }

  /// Par X25519 (pub 32, priv 32).
  ({Uint8List pub, Uint8List priv}) x25519Keypair() {
    final pub = calloc<Uint8>(CryptoSizes.x25519Pub);
    final priv = calloc<Uint8>(CryptoSizes.x25519Priv);
    _b().xKeyPair(pub, priv);
    final p = Uint8List.fromList(pub.asTypedList(CryptoSizes.x25519Pub));
    final s = Uint8List.fromList(priv.asTypedList(CryptoSizes.x25519Priv));
    calloc
      ..free(pub)
      ..free(priv);
    return (pub: p, priv: s);
  }

  /// Acordo X25519 → shared 32 B (usado como chave de sessão via HKDF leve —
  /// aqui BLAKE2b com string fixa de contexto, ver PROTOCOL.md).
  Uint8List x25519Shared(Uint8List myPriv, Uint8List peerPub) {
    final mp = calloc<Uint8>(myPriv.length);
    mp.asTypedList(myPriv.length).setAll(0, myPriv);
    final pp = calloc<Uint8>(peerPub.length);
    pp.asTypedList(peerPub.length).setAll(0, peerPub);
    final out = calloc<Uint8>(CryptoSizes.x25519Shared);
    final rc = _b().xScalar(mp, pp, out);
    calloc
      ..free(mp)
      ..free(pp);
    if (rc != 0) {
      calloc.free(out);
      throw CryptoFailure('X25519 falhou (rc=$rc)');
    }
    final o = Uint8List.fromList(out.asTypedList(CryptoSizes.x25519Shared));
    calloc.free(out);
    return o;
  }

  /// Argon2id + HKDF → [houses…], constantIdx. Determinístico por (pwd,salt).
  ({Uint8List housesLE8, int constantIdx}) deriveKeys(
    Uint8List secret,
    Uint8List salt16,
    int layers,
  ) {
    assert(salt16.length == CryptoSizes.kdfSalt);
    assert(layers >= 1 && layers <= 8);
    final sp = calloc<Uint8>(secret.length);
    sp.asTypedList(secret.length).setAll(0, secret);
    final sa = calloc<Uint8>(CryptoSizes.kdfSalt);
    sa.asTypedList(CryptoSizes.kdfSalt).setAll(0, salt16);
    final casas = calloc<Uint64>(layers);
    final cIdx = calloc<Int32>();
    final rc = _b().deriveKeys(
      sp,
      secret.length,
      sa,
      CryptoSizes.kdfSalt,
      layers,
      casas,
      cIdx,
    );
    calloc
      ..free(sp)
      ..free(sa);
    if (rc != 0) {
      calloc
        ..free(casas)
        ..free(cIdx);
      throw CryptoFailure('derivação de casas falhou (rc=$rc)');
    }
    final le = ByteData(8 * layers);
    for (var i = 0; i < layers; i++) {
      le.setUint64(i * 8, casas[i], Endian.little);
    }
    final c = cIdx.value;
    calloc
      ..free(casas)
      ..free(cIdx);
    return (housesLE8: le.buffer.asUint8List(), constantIdx: c);
  }

  /// AEAD XChaCha20-Poly1305-IETF: plaintext → ct||mac(16).
  /// NOTA: copy‑out; GC do Dart impede zeroização garantida — segredos
  /// persistentes morrem nativamente (docs/THREAT_MODEL §3).
  Uint8List aeadSeal(Uint8List plaintext, Uint8List nonce24, Uint8List key32) {
    assert(nonce24.length == CryptoSizes.aeadNonce);
    assert(key32.length == CryptoSizes.aeadKey);
    final ip = calloc<Uint8>(plaintext.length);
    ip.asTypedList(plaintext.length).setAll(0, plaintext);
    final np = calloc<Uint8>(CryptoSizes.aeadNonce);
    np.asTypedList(CryptoSizes.aeadNonce).setAll(0, nonce24);
    final kp = calloc<Uint8>(CryptoSizes.aeadKey);
    kp.asTypedList(CryptoSizes.aeadKey).setAll(0, key32);
    final outCap = plaintext.length + CryptoSizes.aeadMac;
    final op = calloc<Uint8>(outCap);
    final ol = calloc<Size>();
    final rc = _b().aeadSeal(ip, plaintext.length, np, kp, op, ol);
    calloc
      ..free(ip)
      ..free(np)
      ..free(kp);
    if (rc != 0) {
      calloc
        ..free(op)
        ..free(ol);
      throw CryptoFailure('cifra AEAD falhou (rc=$rc)');
    }
    final outLen = ol.value;
    calloc.free(ol);
    final o = Uint8List.fromList(op.asTypedList(outLen));
    calloc.free(op);
    return o;
  }

  /// AEAD open. Retorna plaintext com chave certa; FALHA (exceção) com
  /// adulteração/chave errada (MAC Poly1305 não perdoa).
  Uint8List aeadOpen(Uint8List ciphertext, Uint8List nonce24, Uint8List key32) {
    assert(nonce24.length == CryptoSizes.aeadNonce);
    assert(key32.length == CryptoSizes.aeadKey);
    if (ciphertext.length <= CryptoSizes.aeadMac) {
      throw CryptoFailure('ciphertext menor que MAC — descartado');
    }
    final ip = calloc<Uint8>(ciphertext.length);
    ip.asTypedList(ciphertext.length).setAll(0, ciphertext);
    final np = calloc<Uint8>(CryptoSizes.aeadNonce);
    np.asTypedList(CryptoSizes.aeadNonce).setAll(0, nonce24);
    final kp = calloc<Uint8>(CryptoSizes.aeadKey);
    kp.asTypedList(CryptoSizes.aeadKey).setAll(0, key32);
    final outCap = ciphertext.length - CryptoSizes.aeadMac;
    final op = calloc<Uint8>(outCap);
    final ol = calloc<Size>();
    final rc = _b().aeadOpen(ip, ciphertext.length, np, kp, op, ol);
    calloc
      ..free(ip)
      ..free(np)
      ..free(kp);
    if (rc != 0) {
      calloc
        ..free(op)
        ..free(ol);
      throw CryptoFailure('decriptação AEAD: MAC inválida ou chave errada');
    }
    final outLen = ol.value;
    calloc.free(ol);
    final o = Uint8List.fromList(op.asTypedList(outLen));
    calloc.free(op);
    return o;
  }
}
