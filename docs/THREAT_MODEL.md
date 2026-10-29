# Modelo de Ameaça — ICOMOS v0.0.1

> **experimental, não auditado**. Auditoria externa não realizada. Este doc é
> a base do produto:define o que protegemos, de quem, e — com o mesmo peso —
> o que **não** protegemos.

## 1. Ativos

| Ativo | Onde | Proteção esperada |
|---|---|---|
| Conteúdo de mensagens (texto/mídia) | em trânsito na LAN; em repouso | E2EE AEAD por mensagem; SQLCipher+cofre do SO em repouso |
| Arquivos | cache/disco | cifrados; cache limpo no wipe |
| Chaves (Ed25519/X25519, sender keys, chave do banco) | cofre do SO (Keystore/libsecret/DPAPI) | nunca em disco em claro, nunca em log |
| Lista de contatos | banco SQLCipher | mesmo sigilo do banco |
| Grupos & memberships | banco | rotacionadas a entrada/saida |
| Metadados (par, frequência, tamanho) | mínimo local | message id random; padding em 1:1 |

## 2. Adversários

- **A1 — Observador passivo na rede local** (Wi-Fi compartilhado, hotspot).
  Vê: IP/MAC, volume, quantidade de pacotes, quando você está on-line.
  Não vê: conteúdo, identidade real, quem é quem dentro do app.
- **A2 — Acesso rápido ao aparelho desbloqueado**.
  Vê: a conversa em tela como você vê. Screenshot: mitigado com
  `FLAG_SECURE` (Android), **mitigação, não garantia** (câmera externa vence).
- **A3 — Apreensão do aparelho em repouso**.
  Face a banco cifrado + chave fora do disco: são dados ilegíveis. Com pânico
  L2 executado antes: **crypto-shredding** — a chave sai, tudo vira lixo.
- **A4 — Dependência de terceiros**. Não existe servidor por design. **Zero-input
  telemetria**, zero analytics, zero crash reporting remoto. Verificável com
  tcpdump: nenhum domínio externo, exceto oferta explícita do usuário de backup
  (v0.2+).
- **A5 — Malware root/kernel**. **FORA DE ESCOPO.** Se adversário vê memória,
  vê chaves — assumido e comunicado.

## 3. Garantias

- Confidencialidade e integridade fim-a-fim por mensagem (AEAD).
- Autenticidade do remetente (Ed25519) e do pareamento (QR assinado +
  desafio-resposta com a chave efêmera + SAS de 6 dígitos).
- Sigilo em repouso (banco cifrado; plaintext só em RAM — nuvem de memória
  Dart não permite guarantee total de zeroização; é documentado).
- Pareamento não reutilizável: QR expira em 15 s; foto fora da janela não serve.
- Minimização de metadados: sem conta/telefone/e-mail/analytics.
- Pânico em 3 níveis com objetivo < 1 s até wipe.

## 4. Não-garantias (declaramos abertamente)

- **Anonimato na LAN**: IP e MAC são visíveis para quem estiver na mesma rede.
- **Disponibilidade sem peer**: contato offline → outbox local, sem relay.
- **Screenshot**: mitigação Android; sem garantia absoluta.
- **Forward secrecy perfeita**: vazamento da identidade permanente expõe as
  sessões construídas com ela. Phase 6 revisa ratchet pós-v0.1.
- **Resistência a root**: fora.
- **Comprovação formal de segurança**: não existe auditoria.

## 5. Linguagem proibida no produto

"inque­brável", "militar", "100% seguro", "criptografia quântica", "à prova
de spyware". A palavra de ordem é **"experimental, não auditado"** — na UI,
no README, em conversa pública.

## 6. Verificações em CI ligadas a este doc

1. Paridade CLI: artefato do app decifrado pelo `martelos` (e vice-versa).
2. Vetores fixos de cripto (KDF, envelope, padding).
3. Adulteração de ciphertext → rejeição; replay → rejeição.
4. QR expirado/ass sinatura inválida/desafio falho → rejeição.
5. Pânico L1/L2/L3 → banco ilegível e sem rasto em cache.
6. Zero telemetria: captura de rede sem domínio externo.
7. Fuzz do codec CBOR e do parser de QR.
