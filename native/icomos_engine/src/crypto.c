/*
 * crypto.c — Primitivas do envelope ICOMOS sobre libsodium.
 *
 * Copyright (c) 2026 Tiago Rabelo da Silva — MIT.
 *
 * Regras: nenhum exit(), nenhum printf; erros por código int.
 * Aleatório SEMPRE por icomos_random (crypto_pwhash/sodium). O GC do Dart
 * impede zeroização garantida do heap gerenciado → buffers sensíveis SÓ
 * aqui em C (memset seguro via sodium_memzero).
 */
#include "../include/icomos_engine.h"
#include <sodium.h>

static int g_sodium_ready = 0;

int icomos_sodium_init(void) {
  if (sodium_init() < 0) return IC_ERR_BASE;
  g_sodium_ready = 1;
  return IC_OK;
}

int icomos_random(uint8_t* out, size_t n) {
  if (!out || n == 0) return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  randombytes_buf(out, n);
  return IC_OK;
}

int icomos_blake2b(const uint8_t* in, size_t in_len,
                   uint8_t* out, size_t out_len) {
  if (!in || !out || out_len == 0 || out_len > crypto_generichash_BYTES_MAX)
    return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  return crypto_generichash(out, out_len, in, in_len, NULL, 0)
             ? IC_ERR_BASE
             : IC_OK;
}

/* ---------------- Ed25519 (assinatura, identidade) ---------------------- */
int icomos_ed25519_keypair(uint8_t pub[32], uint8_t priv[64]) {
  if (!pub || !priv) return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  crypto_sign_keypair(pub, priv);
  return IC_OK;
}

int icomos_ed25519_sign(const uint8_t* msg, size_t msg_len,
                        const uint8_t priv[64], uint8_t sig[64]) {
  if (!msg || !priv || !sig) return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  unsigned long long sig_len = 0;
  crypto_sign_detached(sig, &sig_len, msg, msg_len, priv);
  return (sig_len == 64) ? IC_OK : IC_ERR_BASE;
}

int icomos_ed25519_verify(const uint8_t* msg, size_t msg_len,
                          const uint8_t pub[32], const uint8_t sig[64]) {
  if (!msg || !pub || !sig) return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  /* Convenção libsodium: 0 = válido, -1 = inválido. Propagamos exatamente. */
  return crypto_sign_verify_detached(sig, msg, msg_len, pub);
}

int icomos_ed25519_pk_to_x25519(const uint8_t ed_pub[32], uint8_t x_pub[32]) {
  if (!ed_pub || !x_pub) return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  if (crypto_sign_ed25519_pk_to_curve25519(x_pub, ed_pub) != 0)
    return IC_ERR_BASE;
  return IC_OK;
}

/* ---------------- X25519 (acordo de chaves efêmero) --------------------- */
int icomos_x25519_keypair(uint8_t pub[32], uint8_t priv[32]) {
  if (!pub || !priv) return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  crypto_box_keypair(pub, priv); /* mesma curva do X25519 p/ encaixe depois */
  return IC_OK;
}

int icomos_x25519_scalarmult(const uint8_t my_priv[32],
                             const uint8_t peer_pub[32],
                             uint8_t shared[32]) {
  if (!my_priv || !peer_pub || !shared) return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  if (crypto_scalarmult_curve25519(shared, my_priv, peer_pub) != 0)
    return IC_ERR_BASE;
  return IC_OK;
}

/* ---------------- AEAD XChaCha20-Poly1305-IETF -------------------------- */
int icomos_aead_seal(const uint8_t* in, size_t in_len,
                     const uint8_t nonce[24], const uint8_t key[32],
                     uint8_t* out, size_t* out_len) {
  if (!in || !nonce || !key || !out || !out_len) return IC_ERR_ARG;
  if (!g_sodium_ready) icomos_sodium_init();
  unsigned long long clen = 0;
  if (crypto_aead_xchacha20poly1305_ietf_encrypt(
          out, &clen, in, in_len, NULL, 0, NULL, nonce, key) != 0) {
    return IC_ERR_BASE;
  }
  *out_len = (size_t) clen; /* in_len + 16 (MAC) */
  return IC_OK;
}

int icomos_aead_open(const uint8_t* in, size_t in_len,
                     const uint8_t nonce[24], const uint8_t key[32],
                     uint8_t* out, size_t* out_len) {
  if (!in || !nonce || !key || !out || !out_len) return IC_ERR_ARG;
  if (in_len < 16) return IC_ERR_ARG; /* sem MAC não é ciphertext           */
  if (!g_sodium_ready) icomos_sodium_init();
  unsigned long long plen = 0;
  if (crypto_aead_xchacha20poly1305_ietf_decrypt(
          out, &plen, NULL, in, in_len, NULL, 0, nonce, key) != 0) {
    return IC_ERR_BASE; /* MAC inválida: adulterado ou chave errada */
  }
  *out_len = (size_t) plen;
  return IC_OK;
}
