// crypto_worker.dart — Isolate ÚNICO para o motor MARTELOS + cripto nativa.
//
// REGRA (docs/ADR/0004): o motor NÃO é reentrante — cache estático global
// (motor.c:3-6). Todo acesso FFI passa por UM isolate com fila sequential
// (1 operação em execução por vez). Isolates têm heaps separados: nenhuma
// colisão de estado é possível.
//
// RPC: request → (id, op, args, replyPort); resposta → (id, ok, valor, erro).
// O isolate worker cria o PRÓPRIO EngineClient (lib carregada no heap dele).
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'crypto_api.dart';
import 'engine_client.dart';

/// Exceção da fila (não do motor): isolate fechado, op desconhecida etc.
class WorkerClosed implements Exception {
  WorkerClosed(this.msg);
  final String msg;

  @override
  String toString() => 'WorkerClosed: $msg';
}

/// Resultado de deriveHouses.
class DerivedHouses {
  DerivedHouses(this.housesLE8, this.constantIdx);
  final Uint8List housesLE8;
  final int constantIdx;
}

/// Cliente do isolado único (lado do isolate principal).
class CryptoWorker {
  CryptoWorker._() {
    _replyPort.listen(_onReply);
  }

  final ReceivePort _replyPort = ReceivePort();
  SendPort? _opPort;
  bool _shuttingDown = false;
  final _pending = <int, Completer<Object?>>{};
  int _nextId = 1;

  /// Sobe o isolate e espera o handshake (porta de operações).
  static Future<CryptoWorker> start() async {
    final ready = ReceivePort();
    await Isolate.spawn(
      _entry,
      ready.sendPort,
      debugName: 'icomos-crypto-worker',
    );
    final opPort = await ready.first as SendPort;
    final w = CryptoWorker._().._opPort = opPort;
    ready.close();
    return w;
  }

  /// RPC: idempotente por fila — 1 operação NATIVA em execução qualquer.
  Future<Object?> _call(String op, Map<String, Object?> args) {
    if (_shuttingDown) throw WorkerClosed('worker encerrado');
    final opPort = _opPort;
    if (opPort == null) throw WorkerClosed('worker sem porta de operações');
    final id = _nextId++;
    final c = Completer<Object?>();
    _pending[id] = c;
    opPort.send((id, op, args, _replyPort.sendPort));
    return c.future;
  }

  void _onReply(Object? msg) {
    final m = msg as (int, bool, Object?, String?);
    final c = _pending.remove(m.$1);
    if (c == null) return; // resposta tarde — descarta silenciosamente
    if (m.$2) {
      c.complete(m.$3);
    } else {
      c.completeError(m.$4 != null ? Exception(m.$4) : WorkerClosed('erro'));
    }
  }

  // --- Operações tipadas de alto nível --------------------------------

  Future<Uint8List> textSeal(
    String plaintext,
    List<int> casas,
    int constantIdx, {
    String? formula,
  }) => _call('textSeal', {
    'plaintext': plaintext,
    'casas': casas,
    'constantIdx': constantIdx,
    'formula': formula,
  }).then((r) => r as Uint8List);

  Future<Uint8List> textOpen(
    Uint8List ciphertext,
    List<int> casas,
    int constantIdx, {
    String? formula,
  }) => _call('textOpen', {
    'ct': ciphertext,
    'casas': casas,
    'constantIdx': constantIdx,
    'formula': formula,
  }).then((r) => r as Uint8List);

  Future<DerivedHouses> deriveHouses(
    Uint8List secret,
    Uint8List salt16,
    int layers,
  ) async {
    final r = await _call('deriveKeys', {
      'secret': secret,
      'salt16': salt16,
      'layers': layers,
    });
    final parts = r as List;
    return DerivedHouses(parts[0] as Uint8List, parts[1] as int);
  }

  Future<Uint8List> aeadSeal(
    Uint8List plaintext,
    Uint8List nonce24,
    Uint8List key32,
  ) => _call('aeadSeal', {
    'pt': plaintext,
    'nonce': nonce24,
    'key': key32,
  }).then((r) => r as Uint8List);

  Future<Uint8List> aeadOpen(
    Uint8List ct,
    Uint8List nonce24,
    Uint8List key32,
  ) => _call('aeadOpen', {
    'ct': ct,
    'nonce': nonce24,
    'key': key32,
  }).then((r) => r as Uint8List);

  Future<Uint8List> random(int n) =>
      _call('random', {'n': n}).then((r) => r as Uint8List);

  /// Encerra o isolate (mensagens não-respondidas Completar em erro).
  Future<void> dispose() async {
    _shuttingDown = true;
    for (final c in _pending.values) {
      c.completeError(WorkerClosed('worker encerrado'));
    }
    _pending.clear();
    _replyPort.close();
  }
}

/* ------------------------------- lado worker ----------------------------- */
Future<void> _entry(SendPort readyPort) async {
  final opPort = ReceivePort('icomos-crypto-worker-ops');
  readyPort.send(opPort.sendPort);
  final api = CryptoApi.instance;

  await for (final raw in opPort) {
    final (id, op, args, replyPort) = raw as (int, String, Map, SendPort);
    Object? value;
    String? error;
    try {
      switch (op) {
        case 'textSeal':
          final ec = EngineClient.instance;
          final r = await ec.sealText(
            args['plaintext'] as String,
            houses: List<int>.from(args['casas'] as List),
            constantIdx: args['constantIdx'] as int,
            formula: args['formula'] as String?,
          );
          value = r.bytes;
          break;
        case 'textOpen':
          final ec = EngineClient.instance;
          final r = await ec.openText(
            args['ct'] as Uint8List,
            houses: List<int>.from(args['casas'] as List),
            constantIdx: args['constantIdx'] as int,
            formula: args['formula'] as String?,
          );
          value = r.bytes;
          break;
        case 'deriveKeys':
          final d = api.deriveKeys(
            args['secret'] as Uint8List,
            args['salt16'] as Uint8List,
            args['layers'] as int,
          );
          value = [d.housesLE8, d.constantIdx];
          break;
        case 'aeadSeal':
          value = api.aeadSeal(
            args['pt'] as Uint8List,
            args['nonce'] as Uint8List,
            args['key'] as Uint8List,
          );
          break;
        case 'aeadOpen':
          value = api.aeadOpen(
            args['ct'] as Uint8List,
            args['nonce'] as Uint8List,
            args['key'] as Uint8List,
          );
          break;
        case 'random':
          value = api.randomBytes(args['n'] as int);
          break;
        case 'shutdown':
          replyPort.send((id, true, null, null));
          break;
        default:
          throw WorkerClosed('op desconhecida: $op');
      }
    } catch (e) {
      value = null;
      error = e.toString();
    }
    // Isolates copiam objetos ao enviar (sem ponteiros nativos no wire);
    // não há fugas de memória por aqui.
    replyPort.send((id, error == null, value, error));
  }
}
