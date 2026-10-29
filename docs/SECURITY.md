# SECURITY.md — Política de Segurança

Leia junto com [THREAT_MODEL.md](THREAT_MODEL.md). Classificação global:
**experimental, não auditado**.

## Reporte de vulnerabilidade

- Abra uma **GitHub Issue** (pública) ou fale presencialmente com o autor
  (Tiago Rabelo / HonoravelMacho). Não existe e-mail de segurança.
- Não reporte ataques com root/kernel no aparelho — **fora de escopo** (A5).
- Reporte com: versão, plataforma, passos de reprodução, o que esperava.

## Prioridade de correções

1. Crashes com dados do usuário (double-free do motor, overflow de path).
2. Rejeição falha de adaptação de ciphertext/replay.
3. Vazamento de segredo em log ou no disco.
4. Wipe do pânico que deixa rasto.
5. (Depois) SEO/docs, memória benigna, UI.

## Criptografia em uso

| Fim | Primitiva |
|---|---|
| Assinatura | Ed25519 |
| Acordo de chaves | X25519 (efêmero por sessão) |
| AEAD | XChaCha20-Poly1305 (nonce 24 B aleatório por mensagem) |
| KDF (senhas → motor) | Argon2id (m=64 MiB, t=3, p=1, 32 B) + HKDF-Expand |
| Banco | SQLCipher (AES-256), chave no Keystore/libsecret/DPAPI |
| ID público | BLAKE2b(16 B) → Base32, 26 chars |
| Aleatório | CSPRNG do SO — `Random()` do Dart é proibido (lint no CI) |

## Reprodução do build

```bash
git clone https://github.com/HonoravelMacho/icomos
cd icomos
git submodule update --init --recursive
./tools/fetch-gmp.sh          # Linux: pega header/lib GMP sem root (LGPL v3, fonte)
./native/scripts/build_linux.sh
cd app && flutter test
```

## Obrigação LGPL do GMP (linkagem estática no Windows)

No Windows o GMP é embutido estaticamente em `icomos_engine.dll`. A LGPL v3
exige que o usuário consiga ** relinkar ** a biblioteca. Cumprimos assim:

1. src/gmp version é registrada na release (nota de release + NOTICE);
2. o build é reproduzível com os comandos acima (fontes LGPL abertos);
3. distribuímos a licença LGPL completa junto à release.

No Linux/Android o GMP vem do sistema (pacote lib sendo LGPL) ou é compilado
do código fonte LGPL idêntico — sem alteração de termo.
