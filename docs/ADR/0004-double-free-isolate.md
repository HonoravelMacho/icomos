# ADR 0004 — Worker isolate único + patch do double-free no motor

Status: aceito · Data: 2026-10-29 · Fases 0 e 2

## Contexto
Duas falhas do motor afetam a integração:

1. **Não reentrância**: `CACHE_ESTEIRA`, `TAMANHO_CACHE`, `TIPO_CACHE` são
   `static` (motor.c:3-6) e `strtok` é usado (crypto.c:10). Duas chamadas
   concorrentes corrompem o cache e produzem ciphertext errado — silencioso.
2. **Double-free**: `processar_binario_core` chama `free(cs)` nos caminhos de
   erro (binario.c:529,532,538,544,552,...) enquanto o chamador também dá
   `free` no mesmo ponteiro (main.c:115). Com input adversário, o app aborta.

## Decisão
1. **Arquitetura Dart**: um único `CryptoWorker` (isolate) com fila sequencial
   e backpressure. Contrato: `EngineClient` nunca expõe o isolate; chamadas
   simultâneas enfileiram. FFI de uso geral (não-motor) usa isolates livres.
2. **Patch motor (mínimo, ~2 linhas)**: remover `free(cs);` dos caminhos de
   erro de `processar_binario_core` (propriedade fica no chamador, como o CLI
   já assume). Ao mesmo tempo, a nossa ponte **duplica** o array de casas
   antes de chamar, tornando a ponte robusta mesmo sem o patch (memória que a
   ponte possui). PR upstream proposto separadamente após aceite.

## Consequências
- Zero over-engineering: sem mutex em C, sem third-party.
- Latência serializada: aceitável — operações de motor são O(ms–s) e raras
  por usuário; a fila é por mensagem.
- Se um futuro motor for thread-safe, remover o patch é trivial.
