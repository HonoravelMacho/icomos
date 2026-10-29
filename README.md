# ICOMOS

**Interface de Comunicação e Ocultação com Martelos Open Source** — ou simplesmente: **o chat do Martelos, com QR, envelope tático e pânico de verdade.**

ICOMOS é um chat P2P tático (função de WhatsApp, visual de HUD de jogo sci-fi) que:

- conversa sem conta, sem telefone, sem e-mail, **sem servidor de terceiros**;
- tem **criptografia de ponta a ponta sempre ligada** (Ed25519 + X25519 + XChaCha20-Poly1305);
- adiciona por cima, **opcionalmente por mensagem**, a **Camada Martelos** — cifra o conteúdo com N senhas e gera os formatos oficiais do motor: texto de 34 símbolos, `.bmp`, `.wav`, `.avi` e `.martelos`, **compatíveis com o CLI oficial** do Martelos;
- pareia contatos **apenas presencialmente**, por **QR Code dinâmico** (expira a cada 15 s, assinado, com desafio-resposta e código SAS de 6 dígitos);
- guarda tudo **cifrado no aparelho** (SQLCipher + cofre do SO), com **botão de pânico** que destrói as chaves em menos de 1 segundo (crypto-shredding);
- é **open source (MIT)** e existe para **popularizar o MARTELOS**, permitindo exportar o artefato cifrado para fora do app.

## Status da versão 0.0.1

> **Experimental, não auditado.** Sem auditoria externa de segurança. Não prometemos anonimato de rede (IP/MAC ficam visíveis na LAN), resistência a malware root, ou indisponibilidade quando um contato está offline.

## Arquitetura em 30 segundos

```
                ┌─────────────────────────────────────────────┐
                │                APP                     │
                │  (flutter, pt-BR, HUD sci-fi)          │
                │                                        │
                │ core/ffi ──► libicomos_engine.so/.dll  │──► MARTELOS (35+ blocos)
                │ core/crypto ──► envelope E2EE (XChaCha)│    third_party/martelos
                │ core/transport ──► LAN TCP + mDNS      │    (Apache-2.0)
                │ core/storage ──► SQLCipher + cofre SO  │
                │ core/panic ──► crypto-shredding        │
                └─────────────────────────────────────────────┘
                            ▲                       ▲
                  ┌─────────┴─────────┐  ┌─────────┴──────────┐
                  │  contato (app)     │  │ CLI martelos      │
                  │  mesma LAN         │  │ (abre artefato    │
                  │  sem servidor      │  │  .bmp/.wav/…)     │
                  └───────────────────┘  └────────────────────┘
```

A segurança mora **no envelope** (cada mensagem assinada e cifrada individualmente), **não no transporte**, que é só um cano. A Camada Martelos é artística/portátil, nunca a base de segurança.

## Como rodar (desenvolvimento)

Requisitos: Flutter 3.22+ (testado em 3.44.9), GCC/Clang com `libgmp-dev` no Linux (`sudo apt install libgmp-dev`), Android SDK 36.

```bash
# 1. submódulo do motor (pinado)
git submodule update --init --recursive

# 2. engine nativa (Linux)
./native/scripts/build_linux.sh

# 3. app
cd app && flutter pub get && flutter test
flutter run -d linux      # ou -d <device Android>
```

## Instaladores da Release v0.0.1

Na tag `v0.0.1` o CI publica no GitHub Releases:

- `icomos-0.0.1.apk` (Android arm64-v8a + universal)
- `icomos_0.0.1_amd64.deb` (Linux)
- `icomos-0.0.1.x86_64.rpm` (Linux)
- `icomos-setup-0.0.1.exe` (Windows — **não é assinado**, o SmartScreen pode alertar)
- `icomos-0.0.1-linux.tar.gz` (portátil)
- `SHA256SUMS` (checksums de tudo)

## Estrutura

```
app/         .aplicativo Flutter (Android, Linux, Windows)
native/       engine nativa em C, interface limpa sobre o Martelos
third_party/  submódulo do motor MARTELOS, pinado por SHA
docs/         ameaça, protocolo, segurança, decisões (ADRs)
tools/        vetores de teste, paridade com o CLI oficial, fuzz
```

## Não-garantias (simples e direto)

- **Não dá anonimato** na mesma rede: quem está no Wi-Fi vê que existe tráfego entre os dois.
- **Não é auditado**: experimental até auditoria externa.
- **Não sobrevive a root**
- **Mensagem offline fica na fila** (store-and-forward) — e não é entregue até o contato aparecer.

## Licença

MIT no ICOMOS (veja LICENSE), Apache-2.0 no submódulo MARTELOS, LGPL v3 no GMP — detalhes em NOTICE.
