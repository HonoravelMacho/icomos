/*
 * spike_fase2.c — vetores C da Fase 2: KDF (Argon2id+HKDF), Ed25519
 * sign/verify, X25519, AEAD roundtrip + adulteração.
 * Roda no CI e localmente (LD_LIBRARY_PATH=.).
 */
#include "icomos_engine.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static int fails = 0;
#define CHECK(cond, name) do { \
  if (cond) { printf("[ok] %s\n", name); } \
  else { printf("[FAIL] %s\n", name); fails++; } \
} while (0)

int main(void) {
  CHECK(icomos_sodium_init() == IC_OK, "sodium init");
  CHECK(icomos_abi_version() == 2, "abi v2");

  /* ---- KDF: determinismo, faixa, sensibilidade a salt ---- */
  const uint8_t pwd[] = "MINHA SENHA TATICA SECRETA";
  uint8_t salt1[16], salt2[16];
  uint64_t a1[3], a2[3], b1[3];
  int c1, c2;
  icomos_random(salt1, 16);
  icomos_random(salt2, 16);

  int rc = icomos_derive_keys(pwd, sizeof pwd - 1, salt1, 16, 3, a1, &c1);
  CHECK(rc == IC_OK, "derive keys rc");
  CHECK(c1 >= 1 && c1 != 2, "const_idx em {1,3..7}");
  for (int i = 0; i < 3; i++)
    CHECK(a1[i] >= 1 && a1[i] <= 0x7FFFFFFF, "casa em [1,2^31)");

  rc = icomos_derive_keys(pwd, sizeof pwd - 1, salt1, 16, 3, b1, &c1);
  CHECK(rc == IC_OK && memcmp(a1, b1, sizeof a1) == 0, "determinismo (mesmo salt)");

  rc = icomos_derive_keys(pwd, sizeof pwd - 1, salt2, 16, 3, a2, &c2);
  CHECK(rc == IC_OK && memcmp(a1, a2, sizeof a1) != 0, "salt diferente -> casas diferentes");

  /* ---- Identidade: Ed25519 sign/verify (+ tamper) ---- */
  uint8_t ed_pub[32], ed_priv[64], sig[64];
  const char* msg = "ENVELOPE V1 DE TESTE";
  icomos_ed25519_keypair(ed_pub, ed_priv);
  CHECK(icomos_ed25519_sign((const uint8_t*) msg, strlen(msg), ed_priv, sig) == IC_OK, "sign");
  CHECK(icomos_ed25519_verify((const uint8_t*) msg, strlen(msg), ed_pub, sig) == 0, "verify ok");
  CHECK(icomos_ed25519_verify((const uint8_t*) "ADULTERADO!", 11, ed_pub, sig) == -1, "verify rejeita msg adulterada");

  /* ---- X25519: acordo bilateral igual ---- */
  uint8_t x_pubA[32], x_privA[32], x_pubB[32], x_privB[32], shA[32], shB[32];
  icomos_x25519_keypair(x_pubA, x_privA);
  icomos_x25519_keypair(x_pubB, x_privB);
  CHECK(icomos_x25519_scalarmult(x_privA, x_pubB, shA) == IC_OK, "scalarmult A");
  CHECK(icomos_x25519_scalarmult(x_privB, x_pubA, shB) == IC_OK, "scalarmult B");
  CHECK(memcmp(shA, shB, 32) == 0, "segredo compartilhado igual");

  /* ---- AEAD roundtrip + adulteração + chave errada ---- */
  uint8_t key[32], nonce[24];
  icomos_random(key, 32);
  icomos_random(nonce, 24);
  const char* pt = "SEGREDO E2EE 仮 XCHACHA";
  size_t pt_len = strlen(pt);
  uint8_t ct[512]; size_t ct_len = 0;
  uint8_t dec[512]; size_t dec_len = 0;

  CHECK(icomos_aead_seal((const uint8_t*) pt, pt_len, nonce, key, ct, &ct_len) == IC_OK, "aead seal");
  CHECK(ct_len == pt_len + 16, "ct = pt + 16 (MAC)");
  CHECK(icomos_aead_open(ct, ct_len, nonce, key, dec, &dec_len) == IC_OK && dec_len == pt_len &&
        memcmp(dec, pt, pt_len) == 0, "aead open roundtrip");

  uint8_t ct_bad[512];
  memcpy(ct_bad, ct, ct_len);
  ct_bad[0] ^= 0x01; /* flip 1 bit do ciphertext */
  size_t bl = 0;
  CHECK(icomos_aead_open(ct_bad, ct_len, nonce, key, dec, &bl) != IC_OK, "aead rejeita bit flip");

  size_t wl = 0;
  uint8_t wrong_key[32];
  icomos_random(wrong_key, 32);
  CHECK(icomos_aead_open(ct, ct_len, nonce, wrong_key, dec, &wl) != IC_OK, "aead rejeita chave errada");

  printf(fails == 0 ? "[spike2] TODOS OK\n" : "[spike2] FALHAS\n");
  return fails;
}
