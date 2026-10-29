# PROTOCOL.md — Protocolo ICOMOS v1 (resumo executável)

Este doc acompanha a implementação. Toda alteração precisa de ADR.

## Identidade
- Assinatura: **Ed25519**.
- Chave pública de acordo: X25519.
- ID público: `Base32(BLAKE2b(pub, 16B), 26 chars)`.
- Nome de exibição: **local**; nunca enviado no handshake.

## Handshake 1:1 (mensagens)
1. Efeito X25519 efêmero por sessão com HKDF-SHA256 → chaves por direção.
2. AEAD: **XChaCha20-Poly1305**, nonce de 24 B aleatório.
3. Envelope v1 em **CBOR determinístico** (RFC 8949):
   `{ v=1, msg_id(16B), thread_id(16B), from(26), to[], ts, nonce(24B),
      type, flags, len, sig(64B) }`.
4. Assinatura Ed25519: header canônico + ciphertext.
5. Anti-replay: msg_id único, janela temporal tolerância ±30 s, regras de
   não-reuso; duplicadas — descarte na UI e no banco com registro em audit_log.

## Envelope v1 — detalhes
- Codificação DT: RFC 8949 CBOR **determinístico** (cls canonical, map ord. lex).
- Padding: blocos de 256 B para ocultar tamanho em chats 1:1 curtos (MiTM off).

## Camada MARTELOS (opcional por mensagem)
- Entrada por mensagem: { senhas 1–8, constante (pi/catalan/apery/clausen/arctan/log3 ou formula custom), sub_mode (texto/bmp/wav/avi/martelos) }.
- Senhas → chaves do motor: **Argon2id (m=64 MiB, t=3, p=1, 32 B)** →
  HKDF-Expand → N `uint64` casas em [1, 2^31) + índice de constante.
- **NUNCA** usar `calcular_casa_quiasmo()` como KDF (soma de índices, colide com anagramas).
- Payload de texto grande é fatiado em blocos de ≤ 4 KB (custo do motor cresce
  `cs[0] + len*50 + 1000` dígitos de π por camada em crypto.c:19).
- Entrega de senhas ao destinatário ICOMOS via envelope E2EE opcional (toggle exibido na UI).

## Pareamento (QR)
- Efeito X25519 efêmero por janela de 15 s + nonce 16B + `epoch = floor(unix/15)`.
- QR (CBOR ≈120 B): `{ v, id_pub, eph_pub, epoch, nonce, caps, sig = Ed25519(id_priv, H(campos)) }`.
- Verificação do leitor: assinatura valida; `|epoch_atual − epoch_qr| ≤ 1`; versão
  suportada. Fora disso: **rejeição clara**.
- Transporte LAN: desafio-resposta — leitor nonce, exibidor assina com **eph_priv**.
- SAS de 6 dígitos = HKDF(EPH_keys, "ICOMOS-SAS")[0..2] mod 1e6, exibido nos dois
  aparelhos, com confirmação dos dois lados.

## Transporte v0.0.1
- **LAN TCP + mDNS** (`_icomos._tcp`), TCP puro, sem TLS. A segurança é envelope.
- Sem relay: contato offline → mensagem fica outbox (UI: "aguardando contato").
- Chunking: header + `seq/total` + slice + MAC por chunk; bitmap de ACK.

## Keepalive e reconexão
- Nada de terceiro: keepalive apenas no socket direto e, quando contato aaparece,
  nova tentativa de entrega em backoff 1/2/4/…/120 s.
