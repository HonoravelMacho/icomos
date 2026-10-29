# ADR 0003 — BMP/WAV/AVI nativos em C (sem ffmpeg no Android)

Status: aceito · Data: 2026-10-29 · Fase 5

## Contexto
O motor usa `system("ffmpeg ...")` para imagem/áudio/vídeo (binario.c:164,215-229).
No Android 10+ é proibido executar binários do diretório de dados do app;
empacotar o ffmpeg quebra o tamanho/licenças e agrava o risco.

## Decisão
Implementar em C (nosso `media.c`):
- **BMP 24-bit BGR** (formato já usado pelo motor; sem compressão),
- **WAV PCM 16-bit 44.1kHz** (idem),
- **AVI raw BGR24 + PCM** (container simples, exatamente o que o `martelos`
  produz hoje — os players já o leem).
O modo `.martelos` (arquivo genérico) **não** usa ffmpeg no motor
(`binario.c:592` não é ramo de mídia) e continua como está.

## Consequências
- Comportamento idêntico em Linux/Android/Windows, sem binário externo.
- Vídeo `.avi` raw continua **enorme** (~1 min ≈ centenas de MB) — mitigação
  na UI: limite de 30 s do trecho e estimativa de tamanho antes de enviar (P3).
- No desktop, `ffmpeg` do sistema continua aceito como normalização de input
  (converta antes de enviar), mas nunca obrigatório.
