// cbor.dart — Codificador/decodificador CBOR determinístico (RFC 8949 §4.2).
//
// SUBCONJUNTO para o envelope v1 (docs/PROTOCOL.md): int, bytes (CborBytes),
// string UTF-8, array, map. Regras de determinismo:
//   - ints: codificação mínima (ex.: <24 cabe em 1 byte);
//   - arrays/maps: definite-length sempre;
//   - map: keys ordenadas LEXICOGRAFICAMENTE PELO FORMA CODIFICADA;
//   - decoder estrito: rejeita truncamento, trailing bytes e formas não
//     mínimas (evita same-value-different-encoding = fingerprint).
//
// Representação de dados usada no envelope:
//   int | String | CborBytes | List<Object?> | Map<Object?, Object?>
// (chaves de map são int/String/CborBytes — nunca List/Map, proibição RFC).
import 'dart:convert';
import 'dart:typed_data';

/// Envelope de bytes CBOR de propósito geral.
class CborBytes {
  CborBytes(Uint8List b) : value = Uint8List.fromList(b);
  final Uint8List value;
  @override
  bool operator ==(Object other) =>
      other is CborBytes && _eqBytes(other.value, value);
  @override
  int get hashCode => Object.hashAll(value);
}

bool _eqBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------- encode ---
Uint8List cborEncode(Object? v) {
  final b = BytesBuilder();
  _enc(v, b);
  return b.takeBytes();
}

void _enc(Object? v, BytesBuilder out) {
  if (v is int) {
    if (v < 0) {
      _emitHead(1, -(v + 1), out); // MT1: negativo (com cb -1-n)
    } else {
      _emitHead(0, v, out);
    }
    return;
  }
  if (v is CborBytes) {
    _emitHead(2, v.value.length, out);
    out.add(v.value);
    return;
  }
  if (v is String) {
    final u = utf8.encode(v);
    _emitHead(3, u.length, out);
    out.add(Uint8List.fromList(u));
    return;
  }
  if (v is List) {
    _emitHead(4, v.length, out);
    for (final e in v) {
      _enc(e, out);
    }
    return;
  }
  if (v is Map) {
    // canônico: keys ordenadas pela REPRESENTAÇÃO BINÁRIA.
    final pairs = <(Uint8List, Object?, Object?)>[];
    for (final e in v.entries) {
      final kb = BytesBuilder();
      _enc(e.key, kb);
      pairs.add((kb.takeBytes(), e.key, e.value));
    }
    pairs.sort((a, b) => _cmp(a.$1, b.$1));
    _emitHead(5, pairs.length, out);
    for (final p in pairs) {
      out.add(p.$1); // key já codificada
      _enc(p.$3, out);
    }
    return;
  }
  throw ArgumentError(
    'CBOR: tipo não suportado no envelope v1: ${v.runtimeType}',
  );
}

/// Escreve cabeçalho com menor quantos bytes de leitura.
void _emitHead(int major, int n, BytesBuilder out) {
  assert(n >= 0);
  if (n < 24) {
    out.addByte((major << 5) | n);
  } else if (n <= 0xFF) {
    out.addByte((major << 5) | 24);
    out.addByte(n);
  } else if (n <= 0xFFFF) {
    out.addByte((major << 5) | 25);
    out.addByte((n >> 8) & 0xFF);
    out.addByte(n & 0xFF);
  } else if (n <= 0xFFFFFFFF) {
    out.addByte((major << 5) | 26);
    for (var s = 24; s >= 0; s -= 8) {
      out.addByte((n >> s) & 0xFF);
    }
  } else {
    out.addByte((major << 5) | 27);
    for (var s = 56; s >= 0; s -= 8) {
      out.addByte((n >> s) & 0xFF);
    }
  }
}

int _cmp(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

// ---------------------------------------------------------------- decode ---
class CborDecodeError implements Exception {
  CborDecodeError(this.message);
  final String message;
  @override
  String toString() => 'CborDecodeError: $message';
}

Object? cborDecode(Uint8List data) {
  int pos = 0;
  final v = _dec(data, pos, (p) => pos = p, maxDepth: 16);
  if (pos != data.length) {
    throw CborDecodeError('cbor: trailing bytes ($pos != ${data.length})');
  }
  return v;
}

Object? _dec(
  Uint8List d,
  int pos,
  void Function(int) advance, {
  required int maxDepth,
}) {
  if (maxDepth <= 0) throw CborDecodeError('cbor: profundidade excessiva');
  if (pos >= d.length) throw CborDecodeError('cbor: truncado (header)');
  final ib = d[pos++];
  final major = ib >> 5;
  final minor = ib & 0x1F;

  int len;
  if (minor < 24) {
    len = minor;
  } else if (minor == 24) {
    if (pos >= d.length) throw CborDecodeError('cbor: truncado (arg8)');
    len = d[pos++];
  } else if (minor == 25) {
    if (pos + 2 > d.length) throw CborDecodeError('cbor: truncado (arg16)');
    len = (d[pos] << 8) | d[pos + 1];
    pos += 2;
  } else if (minor == 26) {
    if (pos + 4 > d.length) throw CborDecodeError('cbor: truncado (arg32)');
    len = 0;
    for (var k = 0; k < 4; k++) {
      len = (len << 8) | d[pos + k];
    }
    pos += 4;
  } else if (minor == 27) {
    if (pos + 8 > d.length) throw CborDecodeError('cbor: truncado (arg64)');
    len = 0;
    for (var k = 0; k < 8; k++) {
      len = (len << 8) | d[pos + k];
    }
    pos += 8;
  } else {
    throw CborDecodeError(
      'cbor: subtipo $minor não suportado (indefinite/float/tag)',
    );
  }

  switch (major) {
    case 0:
      advance(pos);
      return len; // inteiro ≥ 0 (não-negativo, canônico)
    case 1:
      advance(pos);
      return -(len + 1);
    case 2:
      if (pos + len > d.length) throw CborDecodeError('cbor: truncado (bytes)');
      final b = Uint8List.fromList(d.sublist(pos, pos + len));
      advance(pos + len);
      return CborBytes(b);
    case 3:
      if (pos + len > d.length) throw CborDecodeError('cbor: truncado (str)');
      final s = utf8.decode(d.sublist(pos, pos + len));
      advance(pos + len);
      return s;
    case 4:
      final list = <Object?>[];
      for (var i = 0; i < len; i++) {
        list.add(_dec(d, pos, (p) => pos = p, maxDepth: maxDepth - 1));
      }
      advance(pos);
      return list;
    case 5:
      final map = <Object?, Object?>{};
      for (var i = 0; i < len; i++) {
        final k = _dec(d, pos, (p) => pos = p, maxDepth: maxDepth - 1);
        final v = _dec(d, pos, (p) => pos = p, maxDepth: maxDepth - 1);
        if (map.containsKey(k)) throw CborDecodeError('cbor: chave duplicada');
        map[k!] = v;
      }
      advance(pos);
      return map;
    default:
      throw CborDecodeError('cbor: major $major não suportado no envelope v1');
  }
}
