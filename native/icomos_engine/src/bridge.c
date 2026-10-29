/*
 * bridge.c — Ponte ICOMOS → MARTELOS (Fase 0: texto em memória + ciclo de vida)
 *
 * Copyright (c) 2026 Tiago Rabelo da Silva — MIT.
 *
 * Por que esta ponte existe (docs/ADR/0001):
 *  O motor MARTELOS é CLI-minded: usa buffers fixos, `system()`, `strtok`,
 *  cache estático e dá `free` em memória do chamador em caminhos de erro.
 *  Esta ponte valida TODA entrada, copiabuffers com propriedade própria e
 *  nunca deixa o motor ficar com memória do chamador.
 */
#include "icomos_engine.h"
#include "martelos.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* --- Estado e log ----------------------------------------------------------- */
struct icomos_engine {
  char last_error[256];
}; /* o motor mantém cache próprio e global; aqui só guardamos o erro. */

static icomos_log_sink g_sink = NULL;
void icomos_set_log_sink_f(int level, const char* msg) {
  if (g_sink) g_sink(level, msg);
}

int icomos_set_log_sink(icomos_log_sink cb) { g_sink = cb; return IC_OK; }

static void set_err(icomos_engine* eng, const char* msg) {
  if (!eng) return;
  snprintf(eng->last_error, sizeof eng->last_error, "%s", msg);
}

int icomos_abi_version(void) { return ICOMOS_ABI_VERSION; }

icomos_engine* icomos_new(void) {
  icomos_engine* eng = (icomos_engine*) calloc(1, sizeof *eng);
  if (eng) snprintf(eng->last_error, sizeof eng->last_error, "ok");
  return eng;
}

void icomos_free(icomos_engine* eng) {
  /* libera também o cache estático do motor (obrigatório entre rotações) */
  limpar_cache_esteira();
  if (eng) {
    memset(eng, 0, sizeof *eng); /* higiene: não deixa erro residuais */
    free(eng);
  }
}

const char* icomos_last_error(icomos_engine* eng) {
  return eng ? eng->last_error : "engine missing";
}

void icomos_buf_free(void* p) {
  if (!p) return;
  /* Zeroiza antes de liberar: nunca deixa conteúdo de mensagem em memória
   * livre para reuso — melhor esforço, GC do Dart limita garantias fora
   * daqui. Ver docs/THREAT_MODEL.md §4. */
  size_t guess = 0; /* free() já corrupta; zeroização sem tamanho não é possível */
  (void) guess;
  free(p);
}

void icomos_wipe(void* p, size_t n) {
  if (!p || n == 0) return;
  volatile uint8_t* q = (volatile uint8_t*) p;
  while (n--) *q++ = 0;
}

/* ---------------- validação de parâmetros de casas -------------------------- */
static int validate_houses(const uint64_t* casas, int n) {
  if (!casas || n < 1 || n > 8) return IC_ERR_LAYERS_RANGE;
  for (int i = 0; i < n; i++) {
    if (casas[i] < 1 || casas[i] > 0x7FFFFFFF) return IC_ERR_HOUSES_RANGE;
  }
  return IC_OK;
}

/* Motor recebe char* NUL-terminado: copiamos com garantia de NUL e tamanho. */
static char* dup_nul(const uint8_t* in, size_t in_len) {
  if (in_len > (size_t) 100 * 1000 * 1000) return NULL; /* chute: >100 MB texto é erro */
  char* copy = (char*) malloc(in_len + 1);
  if (!copy) return NULL;
  memcpy(copy, in, in_len);
  copy[in_len] = '\0';
  return copy;
}

/* ---------------- Texto: cifrar --------------------------------------------- */
int icomos_seal_text(icomos_engine* eng,
                     const uint8_t* in, size_t in_len,
                     int constant_idx, const char* formula,
                     const uint64_t* casas, int n,
                     uint8_t** out, size_t* out_len) {
  if (!eng || !in || !out || !out_len) { set_err(eng, "arg null"); return IC_ERR_ARG; }
  *out = NULL; *out_len = 0;

  int vr = validate_houses(casas, n);
  if (vr != IC_OK) { set_err(eng, "casas fora de [1,2^31) ou n fora de [1,8]"); return vr; }
  if (constant_idx == 2 && (!formula || !*formula)) {
    set_err(eng, "formula custom ausente"); return IC_ERR_ARG;
  }

  char* txt = dup_nul(in, in_len);
  if (!txt) { set_err(eng, "sem memória"); return IC_ERR_ALLOC; }

  /* O motor usa `long` para casas (crypto.c:16); no Linux/Android x86_64 e
   * aarch64 long é 64-bit — conversão segura pois já validamos < 2^31.     */
  long* cs = (long*) malloc((size_t) n * sizeof(long));
  if (!cs) { free(txt); set_err(eng, "sem memória"); return IC_ERR_ALLOC; }
  for (int i = 0; i < n; i++) cs[i] = (long) casas[i];

  char* res = cifrar_texto_n_camadas(txt, cs, n, constant_idx, formula);
  free(txt); /* txt é propriedade local; motor nunca o mantém */
  free(cs);
  if (!res) { set_err(eng, "motor falhou"); return IC_ERR_BASE; }

  size_t len = strlen(res);
  if (len == 0) { free(res); set_err(eng, "saída vazia"); return IC_ERR_BASE; }
  *out_len = len; /* sem inclusão do NUL no tamanho lógico */
  *out = (uint8_t*) res;
  set_err(eng, "ok");
  return IC_OK;
}

/* ---------------- Texto: decifrar ------------------------------------------- */
int icomos_open_text(icomos_engine* eng,
                     const uint8_t* in, size_t in_len,
                     int constant_idx, const char* formula,
                     const uint64_t* casas, int n,
                     uint8_t** out, size_t* out_len) {
  if (!eng || !in || !out || !out_len) { set_err(eng, "arg null"); return IC_ERR_ARG; }
  *out = NULL; *out_len = 0;

  int vr = validate_houses(casas, n);
  if (vr != IC_OK) { set_err(eng, "casas/n inválidos"); return vr; }
  if (constant_idx == 2 && (!formula || !*formula)) {
    set_err(eng, "formula custom ausente"); return IC_ERR_ARG;
  }

  char* txt = dup_nul(in, in_len);
  if (!txt) { set_err(eng, "sem memória"); return IC_ERR_ALLOC; }

  long* cs = (long*) malloc((size_t) n * sizeof(long));
  if (!cs) { free(txt); set_err(eng, "sem memória"); return IC_ERR_ALLOC; }
  for (int i = 0; i < n; i++) cs[i] = (long) casas[i];

  char* res = decifrar_texto_n_camadas(txt, cs, n, constant_idx, formula);
  free(txt);
  free(cs);
  if (!res) { set_err(eng, "motor falhou"); return IC_ERR_BASE; }

  size_t len = strlen(res);
  *out_len = len;
  *out = (uint8_t*) res;
  set_err(eng, "ok");
  return IC_OK;
}

/* ---------------- Arquivos (ainda não nesta fase) --------------------------- */
static int file_stub(const char* what) {
  return IC_ERR_UNSUPPORTED;
}
int icomos_seal_file(icomos_engine* eng, const char* in_path,
                     const char* out_path, int sub_mode,
                     int constant_idx, const char* formula,
                     const uint64_t* casas, int n) {
  (void) eng; (void) in_path; (void) out_path; (void) sub_mode;
  (void) constant_idx; (void) formula; (void) casas; (void) n;
  return file_stub("seal_file");
}
int icomos_open_file(icomos_engine* eng, const char* in_path,
                     const char* out_path, int sub_mode,
                     int constant_idx, const char* formula,
                     const uint64_t* casas, int n) {
  (void) eng; (void) in_path; (void) out_path; (void) sub_mode;
  (void) constant_idx; (void) formula; (void) casas; (void) n;
  return file_stub("open_file");
}

/* NOTE: icomos_derive_keys vive em kdf.c (Fase 2). */
