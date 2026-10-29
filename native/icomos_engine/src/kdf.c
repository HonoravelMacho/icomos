/*
 * kdf.c — Derivação de senhas do usuário → chaves do motor MARTELOS.
 *
 * Copyright (c) 2026 Tiago Rabelo da Silva — MIT.
 *
 * Conforme docs/PROTOCOL.md e docs/ADR/0001:
 *   1. Argon2id (m=64 MiB, t=3, p=1, salt 16 B) → master 32 B (libsodium).
 *   2. crypto_kdf (BLAKE2b) → N subchaves → casas uint64 em [1, 2^31).
 *   3. Índice de constante derivado da PRIMEIRA subchave, em {1,3,4,5,6,7}
 *      (2 = fórmula custom, decisão exclusiva do usuário — nunca de KDF).
 *
 * PROIBIDO usar calcular_casa_quiasmo() como KDF: soma índices após quebrar
 * palavras (crypto.c:8-15) — anagramas colidem.
 */
#include "../include/icomos_engine.h"
#include <sodium.h>

/* Limites do Argon2id conforme spec do dono: 64 MiB / t=3 / p=1. */
#define IC_PWHASH_OPSLIMIT 3
#define IC_PWHASH_MEMLIMIT (64u * 1024u * 1024u) /* 64 MiB */
#define IC_PWHASH_P        1

/* Subchave via crypto_kdf: master 32 B + info = "ICOMOS-casa-<i>".
 * ATENÇÃO: crypto_kdf_derive_from_key EXIGE out_len >= 16 (BYTES_MIN);
 * pedimos 16 e consumimos os 4 primeiros (big-endian). Pedir 4 falha
 * silenciosamente (retorno -1) e casas viram lixo de stack.            */
static uint32_t subkey_u32(const uint8_t master[32], int i) {
  uint8_t sub[16];
  char info[32];
  snprintf(info, sizeof info, "ICOMOS-casa-%d", i);
  crypto_kdf_derive_from_key(sub, sizeof sub, i, info, master);
  /* uint32 dos 4 bytes big-endian. */
  return ((uint32_t) sub[0] << 24) | ((uint32_t) sub[1] << 16) |
         ((uint32_t) sub[2] << 8) | sub[3];
}

int icomos_derive_keys(const uint8_t* secret, size_t secret_len,
                       const uint8_t* salt, size_t salt_len,
                       int layers, uint64_t* casas_out, int* constant_out) {
  if (!secret || secret_len == 0 || !salt || salt_len != 16 ||
      layers < 1 || layers > 8 || !casas_out || !constant_out) {
    return IC_ERR_ARG;
  }
  if (sodium_init() < 0) return IC_ERR_BASE;

  /* Master de 32 B a partir da senha (Argon2id) — equivalente PADRÃO do
   * libsodium crypto_pwhash (Argon2id). Salt é por thread, 16 B
   * aleatório gerado pelo app (nunca derivado da senha). */
  uint8_t master[32];
  if (crypto_pwhash(master, sizeof master, (const char*) secret, secret_len,
                    salt, IC_PWHASH_OPSLIMIT, IC_PWHASH_MEMLIMIT,
                    crypto_pwhash_ALG_ARGON2ID13) != 0) {
    return IC_ERR_BASE; /* memória insuficiente p/ Argon2id */
  }

  for (int i = 0; i < layers; i++) {
    /* Casa em [1, 2^31): subchave 32 bits -> mod 2^31, +1 garante >= 1.   */
    uint32_t u = subkey_u32(master, i);
    if (u == 0) u = 1; /* impossível na prática; defesa barata */
    casas_out[i] = (uint64_t) ((u % 0x7FFFFFFFu)) + 1;
  }

  /* Constante determinística remetente = receptor (derivam o MESMO par):
   * subchave com id fixo 0xFFFF; usamos 1 byte do bloco de 16 (o KDF exige
   * out_len >= crypto_kdf_BYTES_MIN = 16). Mapa {0→1,1→3,2→4,3→5,4→6,5→7}. */
  uint8_t info_out[16];
  crypto_kdf_derive_from_key(info_out, sizeof info_out, 0xFFFF,
                             "ICOMOS-const", master);
  static const int consts[6] = {1, 3, 4, 5, 6, 7};
  *constant_out = consts[info_out[0] % 6];

  /* Higiene: master não fica em heap reutilizado com conteúdo legível. */
  sodium_memzero(master, sizeof master);
  return IC_OK;
}
