// envelope.dart — Envelope v1 do ICOMOS (docs/PROTOCOL.md).
//
// CBOR ARRAY canônico (determinístico por construção, sem sort de keys):
//   [ v=1,
//     msg_id(16B), thread_id(16B), from(32B EdPub), to(Array de 32B),
//     ts(ms), nonce(24B), type, flags,
//     CborBytes(ciphertext || mac), CborBytes(sig 64B) ]
//
// General eta:
//  1) ct = AEAD(key, nonce, payload com padding) — tamanho escondido;
//  2) sig = Ed25519(priv, cbor(header sem sig) || ct);
//  3) wire = cborEncode(header + [ct, sig]).
//
// Ao abrir: checa versão/sizes, CONFERE ASSINATURA antes de decifrar
// (fail-closed), depois AEAD open (Secondary check MAC).
// Padding: prefixo 4B LE comprimento + zeros até múltiplo de 256.
//                                  (esconde tamanho de mensagens curtas)
// Replay: msg_id único/tracing fica na Fase 4 (messaging); o envelope já
//     expose exposição o msg_id e o ts para associação (janela ±30 s).
//
// BUG FIXES: cifra antes da assinatura? NÃO: sign header+ct. Verifica ANTES
//             do aead. Falha nào{retorn geral}.
import 'dart:typed_data';

import '../ffi/crypto_api.dart';
import 'cbor.dart';
import 'identity.dart';

const int kEnvelopeVersion = 1;

/// Tipos-payload do envelope v1 (a expandir na Fase 4: convite grupo etc.).
enum EnvelopeType { text, inviteContact, groupKey, heartbeatOk }

int envelopeTypeCode(EnvelopeType t) => switch (t) {
  EnvelopeType.text => 1,
  EnvelopeType.inviteContact => 2,
  EnvelopeType.groupKey => 3,
  EnvelopeType.heartbeatOk => 4,
};

EnvelopeType envelopeTypeFrom(int code) => switch (code) {
  1 => EnvelopeType.text,
  2 => EnvelopeType.inviteContact,
  3 => EnvelopeType.groupKey,
  4 => EnvelopeType.heartbeatOk,
  _ => throw ArgumentError('envelope: type $code desconhecido'),
};

class EnvelopeException implements Exception {
  EnvelopeException(this.reason);
  final String reason;
  @override
  String toString() => 'EnvelopeException: $reason';
}

/// Mensagem aberta (payload plaintext + metadados do header).
class OpenEnvelope {
  OpenEnvelope({
    required this.msgId,
    required this.threadId,
    required this.fromEdPub,
    required this.to,
    required this.timestampMs,
    required this.type,
    required this.flags,
    required this.plaintext,
  });
  final Uint8List msgId;
  final Uint8List threadId;
  final Uint8List fromEdPub;
  final List<Uint8List> to;
  final int timestampMs;
  final EnvelopeType type;
  final int flags;
  final Uint8List plaintext;
}

/// Envelope v1 — todas as operações são funções puras (sem estado global).
class EnvelopeV1 {
  EnvelopeV1._();

  static const int _kPadBlock = 256;

  /// Sela o payload. Requer Ed25519 do REMETENTE, a CHAVE DE SESSÃO (32B)
  /// e NONCE de 24B aleatório RECÉM-gerado (CryptoApi.randomBytes).
  static Uint8List seal({
    required Uint8List sessionKey32,
    required IcomosIdentity senderIdentity,
    required Uint8List msgId16,
    required Uint8List threadId16,
    required List<Uint8List> recipientsXPub,
    required EnvelopeType type,
    required Uint8List payload,
    int flags = 0,
    int? timestampMs,
  }) {
    final api = CryptoApi.instance;
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    if (msgId16.length != 16 || threadId16.length != 16) {
      throw EnvelopeException('msg_id/thread_id devem ter 16 B');
    }
    if (sessionKey32.length != 32) {
      throw EnvelopeException('chave de sessão deve ter 32 B');
    }
    if (recipientsXPub.isEmpty) {
      throw EnvelopeException('sem destinatário — sem confirmação de quebra');
    }

    // Padding: len(4B LE) || payload || 0… até múltiplo de 256.
    final paddedLen =
        ((payload.length + 4 + _kPadBlock - 1) ~/ _kPadBlock) * _kPadBlock;
    final padded = Uint8List(paddedLen);
    ByteData.sublistView(
      padded,
      0,
      4,
    ).setUint32(0, payload.length, Endian.little);
    padded.setAll(4, payload);

    final nonce24 = api.randomBytes(24);
    final ct = api.aeadSeal(padded, nonce24, sessionKey32);

    final header = <Object?>[
      kEnvelopeVersion,
      CborBytes(msgId16),
      CborBytes(threadId16),
      CborBytes(senderIdentity.edPub),
      recipientsXPub.map(CborBytes.new).toList(),
      ts,
      CborBytes(nonce24),
      envelopeTypeCode(type),
      flags,
    ];
    final headerBytes = cborEncode(header);
    final sig = senderIdentity.sign(_signedBytes(headerBytes, ct));

    final out = [...header, CborBytes(ct), CborBytes(sig)];
    return cborEncode(out);
  }

  /// Abertura fail-closed: erros → EnvelopeException (nunca payload).
  static OpenEnvelope open({
    required Uint8List sessionKey32,
    required Uint8List wire,
    int nowMs = 0,
    int maxAgeMs = 120000, // anti-replay grosso (±2 min na fase 2)
  }) {
    final api = CryptoApi.instance;
    final decoded = cborDecode(wire);
    if (decoded is! List || decoded.length != 11) {
      throw EnvelopeException('estrutura do envelope inválida');
    }

    if ((decoded[0] as int?) != kEnvelopeVersion) {
      throw EnvelopeException('versão de envelope não suportada');
    }
    final msgId = _asBytes(decoded[1], 'msg_id', 16);
    final threadId = _asBytes(decoded[2], 'thread_id', 16);
    final fromPub = _asBytes(decoded[3], 'from', 32);
    final toList = <Uint8List>[];
    final toRaw = decoded[4];
    if (toRaw is! List) throw EnvelopeException('campo "to" inválido');
    for (final r in toRaw) {
      toList.add(_asBytes(r, 'to[]', 32));
    }
    final ts = decoded[5] as int?;
    final nonce = _asBytes(decoded[6], 'nonce', 24);
    final typeCode = decoded[7] as int?;
    final flags = decoded[8] as int?;
    final ct = _asBytes(decoded[9], 'ciphertext', null);
    final sig = _asBytes(decoded[10], 'sig', 64);

    // 1) assinatura do remetente sobre header || ct — ANTES de decifrar.
    final header = decoded.sublist(0, 9);
    // reconstrução da parte assinatura: re-encode determinístico do header.
    final headerBytes = cborEncode(header);
    if (!CryptoApi.instance.ed25519Verify(
      _signedBytes(headerBytes, ct),
      fromPub,
      sig,
    )) {
      throw EnvelopeException('assinatura do remetente inválida');
    }

    // 2) janela temporal (anti-replay grosso; msg_id-dedup vem na Fase 4).
    final now = nowMs == 0 ? DateTime.now().millisecondsSinceEpoch : nowMs;
    if (ts == null || (ts - now).abs() > maxAgeMs) {
      throw EnvelopeException('envelope fora da janela temporal (replay?)');
    }

    // 3) AEAD open (segunda camada de autenticação autêntica).
    //    Chave errada/adulteração → CryptoFailure; convertemos para
    //    EnvelopeException (fail-closed, SEM expor o payload).
    final Uint8List padded;
    try {
      padded = api.aeadOpen(ct, nonce, sessionKey32);
    } on CryptoFailure {
      throw EnvelopeException(
        'AEAD rejeitado: chave errada ou ciphertext alterado',
      );
    }
    if (padded.length < 4) throw EnvelopeException('payload sem comprimento');
    final bd = ByteData.sublistView(padded, 0, 4);
    final plainLen = bd.getUint32(0, Endian.little);
    if (4 + plainLen > padded.length) {
      throw EnvelopeException('comprimento declarado excede o payload');
    }
    final plaintext = Uint8List.sublistView(padded, 4, 4 + plainLen);

    return OpenEnvelope(
      msgId: msgId,
      threadId: threadId,
      fromEdPub: fromPub,
      to: toList,
      timestampMs: ts,
      type: envelopeTypeFrom(typeCode!),
      flags: flags ?? 0,
      plaintext: Uint8List.fromList(plaintext),
    );
  }

  /// Bytes efetivamente assinados: header CBOR || ciphertext.
  static Uint8List _signedBytes(Uint8List headerBytes, Uint8List ct) {
    final b = BytesBuilder(copy: false)
      ..add(headerBytes)
      ..add(ct);
    return b.takeBytes();
  }

  static Uint8List _asBytes(Object? v, String field, int? len) {
    if (v is! CborBytes) throw EnvelopeException('campo "$field" não é bytes');
    if (len != null && v.value.length != len) {
      throw EnvelopeException(
        'campo "$field" com ${v.value.length} B (esperado $len)',
      );
    }
    return v.value;
  }
}
