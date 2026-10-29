/*
 * spike_c.c — teste C rápido do roundtrip (π + texto) antes do FFI Dart.
 * Compila/roda via tools/run_spike.sh; usado no CI Linux.
 */
#include "icomos_engine.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main(void) {
  int fails = 0;
  icomos_engine* e = icomos_new();
  if (!e) { fprintf(stderr, "FAIL: icomos_new\n"); return 1; }

  /* 1. ABI version (v2 = Fase 2: cripto + kdf adicionais) */
  if (icomos_abi_version() < 1) { fprintf(stderr, "FAIL: abi\n"); fails++; }

  /* 2. Roundtrip texto, constante π (idx 1), 3 casas */
  const char* msg = "ATACAR AO AMANHECIDO CMDS OLMEO";
  uint64_t casas[3] = { 424242, 777, 8080 };
  uint8_t* ct = NULL; size_t ct_len = 0;
  int rc = icomos_seal_text(e, (const uint8_t*) msg, strlen(msg),
                            1, NULL, casas, 3, &ct, &ct_len);
  if (rc != IC_OK || !ct) { fprintf(stderr, "FAIL: seal rc=%d err=%s\n", rc, icomos_last_error(e)); return 1; }
  printf("[spike] ciphertext (%zu bytes): %.64s...\n", ct_len, (char*) ct);

  uint8_t* pt = NULL; size_t pt_len = 0;
  rc = icomos_open_text(e, ct, ct_len, 1, NULL, casas, 3, &pt, &pt_len);
  if (rc != IC_OK) { fprintf(stderr, "FAIL: open rc=%d err=%s\n", rc, icomos_last_error(e)); return 1; }
  if (pt_len != strlen(msg) || memcmp(pt, msg, pt_len) != 0) {
    fprintf(stderr, "FAIL: roundtrip difere:\n  orig   = '%s'\n  roundtp= '%.*s'\n",
            msg, (int) pt_len, (char*) pt);
    fails++;
  } else {
    printf("[spike] roundtrip OK\n");
  }
  icomos_buf_free(ct);
  icomos_buf_free(pt);

  /* 3. Validações: n>8 e casas fora do range devem falhar */
  uint64_t bad[9] = {1,1,1,1,1,1,1,1,1};
  if (icomos_seal_text(e, (const uint8_t*)"x", 1, 1, NULL, bad, 9, &ct, &ct_len)
      != IC_ERR_LAYERS_RANGE) { fprintf(stderr, "FAIL: n=9 aceito\n"); fails++; }
  uint64_t big[1] = { 1ULL << 40 };
  if (icomos_seal_text(e, (const uint8_t*)"x", 1, 1, NULL, big, 1, &ct, &ct_len)
      != IC_ERR_HOUSES_RANGE) { fprintf(stderr, "FAIL: casa 2^40 aceita\n"); fails++; }

  icomos_free(e);
  printf(fails == 0 ? "[spike] TODOS OK\n" : "[spike] FALHAS\n");
  return fails;
}
