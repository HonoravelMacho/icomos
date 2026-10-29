// identity.dart — Identidade de longo prazo do ICOMOS (Fase 2 proto).
//
// Composição (docs/PROTOCOL.md §Identidade):
//   - Ed25519  → assinatura de aparelho (64 B privado, 32 público);
//   - X25519   → acordo de chaves (chave pública DERIVADA da Ed25519 —
//                mesma semente, curvas irmãs; menos material p/ backup);
//   - id_pub   → BLAKE2b(pub 16 B) → Base32 RFC4648 → 26 caracteres.
//   - fingerprint → id_pub agrupado de 4, exibido na UI (§11 tela contato).
//   - O NOME DE EXIBIÇÃO é LOCAL: nunca entra no handshake nem no wire.
//
// experimental, não auditado.
import 'dart:typed_data';

import '../ffi/crypto_api.dart';
import 'cbor.dart';

const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// Persistível: recebe `delícitamente` 3 chave-segmentos (Fase 3 lança o
/// cofre). Por ora a identidade vive em RAM dessa classe apenas.
class IcomosIdentity {
  IcomosIdentity._({
    required this.edPub,
    required this.edPriv,
    required this.xPub,
    required this.idRaw16,
  });

  /// 32 B. Chave pública Ed25519.
  final Uint8List edPub;

  /// 64 B. Chave privada Ed25519 (só em RAM; cofre na Fase 3).
  final Uint8List edPriv;

  /// 32 B. Pública X25519 derivada (mesma identidade, curva irmã).
  final Uint8List xPub;

  /// 16 B: BLAKE2b(edPub) — matériaprima do id_pub.
  final Uint8List idRaw16;

  /// Cria identidade nova (aleatório do SO sempre).
  factory IcomosIdentity.generate() {
    final ed = CryptoApi.instance.ed25519Keypair();
    final x = CryptoApi.instance.ed25519PubToX25519(ed.pub);
    final idRaw = CryptoApi.instance.blake2b(ed.pub, outLen: 16);
    return IcomosIdentity._(
      edPub: ed.pub,
      edPriv: ed.priv,
      xPub: x,
      idRaw16: idRaw,
    );
  }

  /// Restaura a partir do backup (cofre na Fase 3).
  factory IcomosIdentity.restore({
    required Uint8List edPriv,
    required Uint8List edPub,
    Uint8List? xPub,
    Uint8List? idRaw,
  }) {
    assert(edPriv.length == 64 && edPub.length == 32);
    final x = xPub ?? CryptoApi.instance.ed25519PubToX25519(edPub);
    final raw = idRaw ?? CryptoApi.instance.blake2b(edPub, outLen: 16);
    return IcomosIdentity._(
      edPub: edPub,
      edPriv: edPriv,
      xPub: x,
      idRaw16: raw,
    );
  }

  /// id público em 26 caracteres Base32 (26 chars = 130 bits ≥ 16 B + pad).
  static final String edAlphabet = _base32Alphabet;
  String get idPub {
    var bits = 0;
    var value = 0;
    final sb = StringBuffer();
    for (final b in idRaw16) {
      value = (value << 8) | b;
      bits += 8;
      while (bits >= 5) {
        sb.write(_base32Alphabet[(value >> (bits - 5)) & 0x1F]);
        bits -= 5;
      }
    }
    if (bits > 0) {
      // últimos bits incompletos: zero-pad (decodificação reversa correta).
      sb.write(_base32Alphabet[(value << (5 - bits)) & 0x1F]);
    }
    return sb.toString(); // 26 chars: 16 B = 128 bits + 2 de padding
  }

  /// Fingerprint agrupado 4-a-4 para leitura humana na UI.
  String get fingerprint {
    final sb = StringBuffer();
    for (var i = 0; i < idPub.length; i++) {
      if (i > 0 && i % 4 == 0) sb.write('-');
      sb.write(idPub[i]);
    }
    return sb.toString();
  }

  /// Assina bytes com a chave privada de longo prazo (Ed25519).
  Uint8List sign(Uint8List msg) => CryptoApi.instance.ed25519Sign(msg, edPriv);

  /// Verifica bytes com a nossa pública (para leitores do próprio apparatus).
  bool verifySelf(Uint8List msg, Uint8List sig) =>
      CryptoApi.instance.ed25519Verify(msg, edPub, sig);

  /// Chuva de bytes codificáveis (CBOR), para wire — payload é byValue bytes.
  Uint8List encodeXPub() => cborEncode(CborBytes(xPub));
}
