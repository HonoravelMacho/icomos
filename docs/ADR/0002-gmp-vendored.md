# ADR 0002 — GMP vendido (sem sudo) + fonte LGPL no build local

Status: aceito · Data: 2026-10-29 · Fase 0

## Contexto
`gmp.h` não está instalado na máquina de desenvolvimento e `sudo` exige senha
que a sessão agente não possui. O CI (ubuntu-22.04) pode instalar `libgmp-dev`
normalmente, mas o **build local** precisa funcionar sem root.

## Decisão
- `tools/fetch-gmp.sh`: baixa **GMP 6.3.0** (fonte oficial LGPL), compila
  estático (`--disable-shared --enable-static --with-pic --disable-assembly`),
  CFLAGS `-O2 -fPIC`, e instala em `third_party/gmp/<triplet>` —
  **gitignored** (nunca commitamos binário).
- `native/scripts/build_linux.sh` procura headers nesta ordem:
  `third_party/gmp` → `/usr/include` (libgmp-dev do sistema).
- CI usa `libgmp-dev` do apt (mais rápido e idiomático), o que torna o
  fetch-gmp.sh apenas ferramenta de desenvolvedor.

## Consequências
- Build local reproduzível sem root.
- LGPL: fonte é o tarball oficial intacto; NOTICE/SECURITY documentam relink.
- No Android/Windows a mesma ferramenta será reutilizada (cross-compile).
