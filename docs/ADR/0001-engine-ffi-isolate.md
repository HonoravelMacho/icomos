# ADR 0001 — Isolamento do motor MARTELOS por uma C ABI própria (`libicomos_engine`)

Status: aceito · Data: 2026-10-29 · Fase 0/2

## Contexto
Motor real tem:
- cache estático global (`motor.c:3-6`) — **não reentrante**;
- `strtok` no KDF (`crypto.c:10`);
- `free(cs)` em caminhos de erro (`binario.c:529,532,538,544,552,...`) enquanto o CLI chama
  `free(chaves)` também (`main.c:115`) → **double-free**;
- buffers fixos 2048/4096 usados com `strcpy`/`sprintf` e nomes de arquivo (`binario.c:517,537,882`)
  → overflow com path longo;
- `system("ffmpeg ...")` em imagem/áudio/vídeo (`binario.c:164,215,225,229)`.

## Decisão
- Toda a superfí­cie do motor passa por **`libicomos_engine`** (C ABI própria):
  `icomos_new/free/derive_keys/seal/open/seal_file/open_file/buf_free/wipe/last_error`.
- **Um único isolate Dart (`CryptoWorker`)** acessa o motor. Nenhum outro código toca FFI.
- Path de arquivo do usuário **nunca** vai direto ao motor; wrapper copia para
  path interno < 200 chars, valida, chama, devolve.
- Double-free será corrigido com **patch mínimo no binario.c** (remover `free(cs)`
  dos caminhos de erro) e proposto como PR a `HonoravelMacho/martelos`.
- As senhas do usuário **nunca** passam por `calcular_casa_quiasmo()`; elas entram
  Argon2id + HKDF no nosso `kdf.c` e chegam como `casas[] uint64 já derivadas`.

## Consequências
- +1 camada entre app e motor (~600 LOC in C).
- Corrige crash silencioso (R1/R2) e overflow (R3) **sem reescrever o motor**.
- Motor pode evoluir/saber que camada se mantém (compat chrono CLI).
