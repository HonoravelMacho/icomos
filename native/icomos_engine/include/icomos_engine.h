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

/* Código de versão da ABI — aumenta quando a ASSINATURA de qualquer função
 * mudar. Funções ADICIONADAS não mudam a versão (nova função = novo símbolo). */
#define ICOMOS_ABI_VERSION 2
#define IC_OK 0

/* Tamanhos fixos de criptografia (libsodium, docs/PROTOCOL.md §cripto). */
#define IC_ED25519_PUB  32
#define IC_ED25519_PRIV 64
#define IC_ED25519_SIG  64
#define IC_X25519_PUB   32
#define IC_X25519_PRIV  32
#define IC_X25519_SHARED 32
#define IC_AEAD_NONCE   24
#define IC_AEAD_KEY     32
#define IC_AEAD_MAC     16
#define IC_KDF_SALT     16
#define IC_KDF_OUT      32

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

/* ---------------- Derivação de chaves (senhas → motor) ---------------------
 * Argon2id (m=64 MiB, t=3, p=1, saída 32 B) + HKDF-like (crypto_kdf BLAKE2b)
 * → N casas uint64 em [1, 2^31) + índice de constante em {1,3,4,5,6,7}
 * (2 = fórmula custom e NUNCA sai de KDF — é escolha do usuário na UI).
 * PROIBIDO usar calcular_casa_quiasmo() como KDF (docs/ADR/0001).
 * `casas_out`: buffer do chamador com espaço para `layers` valores.        */
int icomos_derive_keys(const uint8_t* secret, size_t secret_len,
                       const uint8_t* salt, size_t salt_len,
                       int layers, uint64_t* casas_out, int* constant_out);

/* --------------- Criptografia de envelope (libsodium 1.0.20) --------------
 * Tudo EXPERIMENTAL — não auditado (docs/THREAT_MODEL.md).                 */
/* sodium_init() idempotente; chamar uma vez por processo.                   */
int icomos_sodium_init(void);

/* aleatório criptográfico do SO — ÚNICO caminho de aleatório (proibido Dart
 * Random(); ver §6.6 do briefing).                                          */
int icomos_random(uint8_t* out, size_t n);

/* hash BLAKE2b genérico (generichash) — id público e fingerprints.          */
int icomos_blake2b(const uint8_t* in, size_t in_len,
                   uint8_t* out, size_t out_len);

/* Ed25519: geração, assinatura, verificação e conversão p/ X25519.          */
int icomos_ed25519_keypair(uint8_t pub[32], uint8_t priv[64]);
int icomos_ed25519_sign(const uint8_t* msg, size_t msg_len,
                        const uint8_t priv[64], uint8_t sig[64]);
/* retorna 0 quando válido, -1 quando INVÁLIDO (convenção libsodium).       */
int icomos_ed25519_verify(const uint8_t* msg, size_t msg_len,
                          const uint8_t pub[32], const uint8_t sig[64]);
int icomos_ed25519_pk_to_x25519(const uint8_t ed_pub[32], uint8_t x_pub[32]);

/* X25519: par + acordo de chaves (shared 32 B para HKDF contexto fixo).     */
int icomos_x25519_keypair(uint8_t pub[32], uint8_t priv[32]);
int icomos_x25519_scalarmult(const uint8_t my_priv[32],
                             const uint8_t peer_pub[32],
                             uint8_t shared[32]);

/* AEAD XChaCha20-Poly1305-IETF: out = ciphertext || mac(16 B).
 * in/out_len incluem a mac no open (in) e no seal (out).                    */
int icomos_aead_seal(const uint8_t* in, size_t in_len,
                     const uint8_t nonce[24], const uint8_t key[32],
                     uint8_t* out, size_t* out_len);
int icomos_aead_open(const uint8_t* in, size_t in_len,
                     const uint8_t nonce[24], const uint8_t key[32],
                     uint8_t* out, size_t* out_len);

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
