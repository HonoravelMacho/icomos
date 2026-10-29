/*
 * icomos_engine.h — C ABI da ponte ICOMOS → MARTELOS (v0.0.1, Fase 0/2)
 *
 * Copyright (c) 2026 Tiago Rabelo da Silva — MIT.
 *
 * REGRAS INVIOÁVEIS (ver docs/ADR/0001 e docs/ADR/0004):
 *  - `casas` é SEMPRE do chamador: o motor nunca recebe propriedade dela.
 *  - Nenhum `exit()`, nenhum `printf` em modo biblioteca.
 *  - Todo buffer de saída é liberado por icomos_buf_free().
 *  - Um único contexto `icomos_engine` por processo deve ser usado por vez:
 *    o motor MARTELOS mantém cache estático (motor.c:3-6) e NÃO é reentrante.
 *    No Dart, isso é garantia do CryptoWorker (isolate único).
 *  - Caminhos de arquivo do usuário NUNCA passam sem validação: o chamador
 *    deve garantí-los < 200 bytes (buffers fixos em binario.c:517/882).
 */
#ifndef ICOMOS_ENGINE_H
#define ICOMOS_ENGINE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Código de versão da ABI — aumenta quando mudar a assinatura de qualquer função. */
#define ICOMOS_ABI_VERSION 1
#define IC_OK 0

/* Erros (positivos para usarmos -1..-9 sem colidr com códigos do motor). */
enum {
  IC_ERR_BASE              = -1,
  IC_ENGINE_MISSING        = -2, /* contexto não alocado                        */
  IC_ERR_ARG               = -3, /* argumento inválido (NULL, len, etc.)        */
  IC_ERR_UNSUPPORTED       = -4, /* ainda não implementado nesta fase           */
  IC_ERR_HOUSES_RANGE      = -5, /* casas fora de [1, 2^31)                      */
  IC_ERR_LAYERS_RANGE      = -6, /* n senhas fora de [1, 8]                      */
  IC_ERR_PATH_TOO_LONG     = -7, /* path >= 200 bytes (overflow do motor)        */
  IC_ERR_ALLOC             = -8  /* falta de memória                             */
};

typedef struct icomos_engine icomos_engine;
typedef void (*icomos_log_sink)(int level, const char* msg);

/* ---------------- Ciclo de vida ---------------- */
int icomos_abi_version(void);
icomos_engine* icomos_new(void);
void icomos_free(icomos_engine* eng);

/* ---------------- Derivação de chaves (Fase 2 — agora IC_ERR_UNSUPPORTED)
 * Converte segredo do usuário (Argon2id + HKDF dentro da lib) em N "casas"
 * uint64 no intervalo [1, 2^31) + índice da constante, para uso no motor.
 * `casas_out` é buffer do chamador, com espaço para até `n` valores.       */
int icomos_derive_keys(const uint8_t* secret, size_t secret_len,
                       const uint8_t* salt, size_t salt_len,
                       int layers, uint64_t* casas_out, int* constant_out);

/* ---------------- Texto (memória) — CIFRAR/DECIFRAR em 1..8 camadas -------
 * `in_len` é em BYTES e `in` NÃO precisa ser NUL-terminado (a ponte copia).
 * IMPORTANTE: o motor é lossy (remove acentos, força MAIÚSCULAS e troca
 * caracteres fora do alfabeto de 34 símbolos por '-') — documentado na UI.
 * `constant_idx`: 1=pi 2=formula custom 3=catalan 4=apery 5=clausen 6=arctan 7=log3
 * `formula`: fórmula custom (só usada se constant_idx==2); NULL caso contrário.
 * `casas`: array de `n` valores uint64 (cada um em [1, 2^31)).
 * `n`: 1..8 senhas ("casas").
 * Saída: buffer único NUL-terminado, liberado com icomos_buf_free().          */
int icomos_seal_text(icomos_engine* eng,
                     const uint8_t* in, size_t in_len,
                     int constant_idx, const char* formula,
                     const uint64_t* casas, int n,
                     uint8_t** out, size_t* out_len);
int icomos_open_text(icomos_engine* eng,
                     const uint8_t* in, size_t in_len,
                     int constant_idx, const char* formula,
                     const uint64_t* casas, int n,
                     uint8_t** out, size_t* out_len);

/* ---------------- Arquivos (Fase 2/5) ------------------------------------- */
int icomos_seal_file(icomos_engine* eng, const char* in_path,
                     const char* out_path, int sub_mode,
                     int constant_idx, const char* formula,
                     const uint64_t* casas, int n);
int icomos_open_file(icomos_engine* eng, const char* in_path,
                     const char* out_path, int sub_mode,
                     int constant_idx, const char* formula,
                     const uint64_t* casas, int n);

/* ---------------- Memória / debug ---------------- */
void icomos_buf_free(void* p);
void icomos_wipe(void* p, size_t n);
const char* icomos_last_error(icomos_engine* eng);
/* Log roteado (sem printf direto); level: 0=debug 1=info 2=warn 3=error. */
int icomos_set_log_sink(icomos_log_sink cb);

#ifdef __cplusplus
}
#endif
#endif /* ICOMOS_ENGINE_H */
