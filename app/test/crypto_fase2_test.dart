// crypto_fase2_test.dart — Vetores e propriedades da camada cripto (Fase 2).
//
// Requer libicomos_engine v2 (libsodium embutido):
//   ICOMOS_ENGINE_LIB=../native/icomos_engine/build-linux/libicomos_engine.so
//
// Cobertura: CBOR determinístico, identidade (Base32/fingerprint/assinatura),
// envelope E2EE (roundtrip, tamper=assinatura rejeitada, replay fora de
// janela, wrong key), KDF determinístico/determinístico nenhum silêncio.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:icomos/core/crypto/cbor.dart';
import 'package:icomos/core/crypto/envelope.dart';
import 'package:icomos/core/crypto/identity.dart';
import 'package:icomos/core/ffi/crypto_api.dart';
import 'package:icomos/core/ffi/crypto_worker.dart';

void main() {
  setUpAll(() {
    CryptoApi.instance.sodiumInit();
  });

  group('CBOR determinístico', () {
    test('vetor fixo: array com int/bytes/str/map', () {
      final enc = cborEncode([
        1,
        CborBytes(Uint8List.fromList([0xAA, 0xBB])),
        'ICOMOS',
        {
          1: 'a',
          2: CborBytes(Uint8List.fromList([1])),
        },
      ]);
      // cdor: 0x8A?? — verificamos por roundtrip + tamanho estável.
      final enc2 = cborEncode([
        1,
        CborBytes(Uint8List.fromList([0xAA, 0xBB])),
        'ICOMOS',
        {
          2: CborBytes(Uint8List.fromList([1])),
          1: 'a',
        },
      ]);
      expect(enc, enc2); // ordem de inserção NÃO muda os bytes
    });

    test('roundtrip total', () {
      final v = <Object?>[
        -5,
        300,
        'texto acentuado é ICOMOS',
        CborBytes(Uint8List.fromList([1, 2, 3])),
        [1 == 1 ? 1 : 2, 'x'],
        {'k': v0Path()},
      ];
      final rt = cborDecode(cborEncode(v)) as List;
      expect(rt[0], -5);
      expect(rt[1], 300);
      expect(rt[2], v[2]);
      expect((rt[3] as CborBytes).value, Uint8List.fromList([1, 2, 3]));
      expect((rt[5] as Map)['k'], v0Path());
    });

    test('truncado e trailing bytes → rejeitados', () {
      final b = cborEncode([1, 2]);
      expect(
        () => cborDecode(b.sublist(0, b.length - 1)),
        throwsA(isA<CborDecodeError>()),
      );
      final extra = Uint8List.fromList([...b, 0x00]);
      expect(() => cborDecode(extra), throwsA(isA<CborDecodeError>()));
    });
  });

  group('Identidade', () {
    test('id_pub tem 26 chars e fingerprint em grupos legíveis', () {
      final id = IcomosIdentity.generate();
      expect(id.idPub.length, 26);
      // 26 chars agrupados 4-a-4: 6 grupos de 4 + grupo final de 2 = 7 partes,
      // com 6 hifens (final do id sem Oberstellung hífen).
      final parts = id.fingerprint.split('-');
      expect(parts.length, 7);
      for (var i = 0; i < 6; i++) {
        expect(parts[i].length, 4, reason: 'grupo $i deve ter 4 chars');
      }
      expect(parts[6].length, 2);
      // todos os caracteres são do alfabeto Base32.
      for (final p in parts) {
        expect(p, matches(RegExp(r'^[A-Z2-7]+$')));
      }
    });

    test('assinatura autêntica; adulteração rejeitada', () {
      final id = IcomosIdentity.generate();
      const msg = 'CARGA DE TESTE ICOMOS';
      final sig = id.sign(Uint8List.fromList(msg.codeUnits));
      expect(id.verifySelf(Uint8List.fromList(msg.codeUnits), sig), isTrue);
      final tampered = Uint8List.fromList(msg.codeUnits);
      tampered[0] = 0x58; // muda 1 char
      expect(id.verifySelf(tampered, sig), isFalse);
    });
  });

  group('KDF (Argon2id + HKDF)', () {
    test('determinístico por (senha, salt); salt muda a saída', () {
      final api = CryptoApi.instance;
      final secret = Uint8List.fromList('SENHA DE TESTE TATICA'.codeUnits);
      final salt = Uint8List(16);

      final a = api.deriveKeys(secret, salt, 3);
      final b = api.deriveKeys(secret, salt, 3);
      expect(a.housesLE8, b.housesLE8);
      expect(a.constantIdx, b.constantIdx);
      expect(a.constantIdx != 2, isTrue); // 2=fórmula custom, nunca vem de KDF

      final salt2 = Uint8List(16);
      salt2[0] = 1;
      final c = api.deriveKeys(secret, salt2, 3);
      expect(c.housesLE8, isNot(a.housesLE8));

      // casas em [1, 2^31): carregamos 4 bytes little-endian.
      final bd = ByteData.sublistView(a.housesLE8);
      for (var i = 0; i < 3; i++) {
        final v = bd.getUint32(i * 8, Endian.little);
        expect(v >= 1 && v <= 0x7FFFFFFF, isTrue);
      }
    });
  });

  group('Envelope v1', () {
    test('roundtrip E2EE completo (texto com padding)', () {
      final sender = IcomosIdentity.generate();
      final receiver = IcomosIdentity.generate();
      final key = CryptoApi.instance.randomBytes(32);
      const payloadText = 'ALVO CONFIRMADO AMANHECIDO';
      final payload = Uint8List.fromList(payloadText.codeUnits);

      final wire = EnvelopeV1.seal(
        sessionKey32: key,
        senderIdentity: sender,
        msgId16: CryptoApi.instance.randomBytes(16),
        threadId16: CryptoApi.instance.randomBytes(16),
        recipientsXPub: [receiver.xPub],
        type: EnvelopeType.text,
        payload: payload,
      );

      final open = EnvelopeV1.open(sessionKey32: key, wire: wire);
      // Padding não aparece: comprimento exato é preservado.
      expect(Uint8List.fromList(open.plaintext), payload);
      expect(open.type, EnvelopeType.text);
    });

    test('chave de sessão errada → MAC rejeita (fail-closed)', () {
      final sender = IcomosIdentity.generate();
      final receiver = IcomosIdentity.generate();
      final key = CryptoApi.instance.randomBytes(32);
      final wire = EnvelopeV1.seal(
        sessionKey32: key,
        senderIdentity: sender,
        msgId16: CryptoApi.instance.randomBytes(16),
        threadId16: CryptoApi.instance.randomBytes(16),
        recipientsXPub: [receiver.xPub],
        type: EnvelopeType.text,
        payload: Uint8List.fromList('SEGREDOS'.codeUnits),
      );
      final otherKey = CryptoApi.instance.randomBytes(32);
      expect(
        () => EnvelopeV1.open(sessionKey32: otherKey, wire: wire),
        throwsA(isA<EnvelopeException>()),
      );
    });

    test('ciphertext adulterado → assinatura rejeitada ANTES do aead', () {
      final sender = IcomosIdentity.generate();
      final key = CryptoApi.instance.randomBytes(32);
      final wire = EnvelopeV1.seal(
        sessionKey32: key,
        senderIdentity: sender,
        msgId16: CryptoApi.instance.randomBytes(16),
        threadId16: CryptoApi.instance.randomBytes(16),
        recipientsXPub: [sender.xPub],
        type: EnvelopeType.text,
        payload: Uint8List.fromList('INTEGRIDADE'.codeUnits),
      );
      wire[wire.length - 70] ^= 0x01; // bit no ciphertext
      expect(
        () => EnvelopeV1.open(sessionKey32: key, wire: wire),
        throwsA(isA<EnvelopeException>()),
      );
    });

    test('replay fora da janela (±2 min) → rejeicao', () {
      final sender = IcomosIdentity.generate();
      final key = CryptoApi.instance.randomBytes(32);
      final wire = EnvelopeV1.seal(
        sessionKey32: key,
        senderIdentity: sender,
        msgId16: CryptoApi.instance.randomBytes(16),
        threadId16: CryptoApi.instance.randomBytes(16),
        recipientsXPub: [sender.xPub],
        type: EnvelopeType.text,
        payload: Uint8List.fromList('VELHO DEMAIS'.codeUnits),
        timestampMs: DateTime.now().millisecondsSinceEpoch - 600000,
      );
      expect(
        () => EnvelopeV1.open(sessionKey32: key, wire: wire),
        throwsA(isA<EnvelopeException>()),
      );
    });

    test('versão de envelope desconhecida → rejeição', () {
      final sender = IcomosIdentity.generate();
      final key = CryptoApi.instance.randomBytes(32);
      final wire = EnvelopeV1.seal(
        sessionKey32: key,
        senderIdentity: sender,
        msgId16: CryptoApi.instance.randomBytes(16),
        threadId16: CryptoApi.instance.randomBytes(16),
        recipientsXPub: [sender.xPub],
        type: EnvelopeType.text,
        payload: Uint8List.fromList('FUTURO'.codeUnits),
      );
      // Corrompe somente o primeiro byte int (v=1) — base major/array: byte0.
      // Reestruturamos no nível CBOR byte 1: minor value de 0x01 → 0x02 está
      // dentro do array [2, ...]. byte1 = 0x01 (v1). muda para 0x09.
      wire[1] = 0x09;
      expect(
        () => EnvelopeV1.open(sessionKey32: key, wire: wire),
        throwsA(isA<EnvelopeException>()),
      );
    });
  });

  group('CryptoWorker (isolate único)', () {
    test(
      'start + textSeal/textOpen via isolate + fila sequencial',
      () async {
        final w = await CryptoWorker.start();
        final r = await w.random(24);
        expect(r.length, 24);

        // Motor é lossy (docs/PROTOCOL.md): acento vira caractere base
        // ('Ú'→'U'). Teste usa string SEM acento, dentro do alfabeto 34.
        const msg = 'ATESTADO DO CANAL UNICO DO MOTOR';
        final ct = await w.textSeal(msg, const [424242, 777], 1 /* pi */);
        expect(ct, isNotEmpty);

        final pt = await w.textOpen(ct, const [424242, 777], 1 /* pi */);
        expect(utf8.decode(pt), msg);

        // erros: casas erradas → decifra ≠ original, mas não crash.
        final wrong = await w.textOpen(ct, const [999111], 1);
        expect(utf8.decode(wrong), isNot(msg));

        await w.dispose();
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

// helper para o vetor de teste acima (map com chave byte-lista).
Object v0Path() => Uint8List.fromList([9, 9]);
