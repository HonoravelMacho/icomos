// Teste de Fase 0: roundtrip FFI Dart → libicomos_engine → motor MARTELOS.
//
// Requisito do gate: "spike FFI (π + roundtrip) — `.so` carrega" (roadmap).
// O ambiente de teste define ICOMOS_ENGINE_LIB ou o loader resolve pelos
// caminhos padrão (build-linux, bundle).
import 'package:flutter_test/flutter_test.dart';

import 'package:icomos/core/ffi/bindings.dart';
import 'package:icomos/core/ffi/engine_client.dart';

void main() {
  test('ABI version é 1', () {
    expect(bindings().abiVersion(), 1);
  });

  test('roundtrip: cifra com π + 3 casas → decifra idêntico', () async {
    // Alfabeto do motor: A–Z, espaço e 7 pontuações — dígitos NÃO são
    // suportados (viram '-'). Ver alfabeto.c:2-5 e o aviso na UI.
    const msg = 'ATACAR AO AMANHECIDO CMD OLMEO';
    final client = EngineClient.instance;

    final ct = await client.sealText(
      msg,
      houses: const [424242, 777, 8080],
      constantIdx: MartelosConstant.pi,
    );
    expect(ct.bytes, isNotEmpty);

    final pt = await client.openText(
      ct.bytes,
      houses: const [424242, 777, 8080],
      constantIdx: MartelosConstant.pi,
    );
    expect(pt.asText, msg);
  });

  test('senhas erradas NÃO decifram', () async {
    const msg = 'MENSAGEM SECRETA OK';
    final client = EngineClient.instance;
    final ct = await client.sealText(
      msg,
      houses: const [111, 222, 333],
      constantIdx: MartelosConstant.pi,
    );
    final wrong = await client.openText(
      ct.bytes,
      houses: const [999, 888, 777],
      constantIdx: MartelosConstant.pi,
    );
    expect(wrong.asText, isNot(msg));
  });

  test('cifras com constantes diferentes divergem', () async {
    const msg = 'MESMA MENSAGEM CONSTANTES DIFERENTES';
    final client = EngineClient.instance;
    final ctPi = await client.sealText(
      msg,
      houses: const [42],
      constantIdx: MartelosConstant.pi,
    );
    final ctLog3 = await client.sealText(
      msg,
      houses: const [42],
      constantIdx: MartelosConstant.log3,
    );
    expect(ctPi.asText, isNot(ctLog3.asText));
  });
}
