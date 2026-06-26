---
title: Verificação de webhooks da NFE.io
sidebar_label: Webhooks
sidebar_position: 5
description: Verifique a assinatura HMAC-SHA1 das entregas de webhook da NFE.io com Nfe::Webhook, leia o corpo cru antes de parsear o JSON e torne seus handlers idempotentes.
---

# Webhooks

Em vez de fazer polling até um estado terminal, você pode receber a conclusão da
emissão por push. A NFE.io entrega um webhook; seu endpoint **verifica a
assinatura** e reage ao evento. Este guia cobre a verificação canônica via
`Nfe::Webhook`.

## Como a NFE.io assina as entregas

Cada entrega traz o cabeçalho `X-Hub-Signature` com um HMAC-SHA1 calculado sobre
os **bytes exatos** do corpo da requisição, no formato `sha1=<40 hex>`:

```text
X-Hub-Signature: sha1=BCD17C02B9E3B40A18E745E7E04247E4AD2DD935
```

:::warning Documentação antiga está errada
Apenas o esquema `X-Hub-Signature` + **HMAC-SHA1** é suportado. Material de
distribuição mais antigo que menciona `X-NFe-Signature`, **SHA-256** ou
**Base64** está incorreto — um cabeçalho `sha256=` é rejeitado.
:::

## A API de verificação

`Nfe::Webhook` é um módulo de funções **sem estado**: não precisa de um
`Nfe::Client`, não lê a `Nfe::Configuration` e não faz nenhuma chamada de rede.
Você fornece os três argumentos: o corpo cru, o valor do cabeçalho e o segredo.

```ruby
require "nfe"

ok = Nfe::Webhook.verify_signature(
  payload: raw_body,
  signature: signature_header,
  secret: ENV.fetch("NFE_WEBHOOK_SECRET")
)
```

### `verify_signature` → Boolean

Retorna `true` **somente** quando o HMAC-SHA1 confere exatamente. A comparação é
feita em tempo constante (`OpenSSL.secure_compare`) e o prefixo `sha1=` é
comparado de forma **case-insensitive** (a NFE.io envia o hex em maiúsculas).

:::tip Nunca levanta exceção
`verify_signature` **nunca** levanta. Qualquer entrada ausente, malformada, com
algoritmo errado, comprimento errado ou conteúdo não-hexadecimal resulta em
`false`. Um segredo ou assinatura `nil`/vazia também retorna `false`.
:::

Se o cabeçalho chegar como um array de um elemento (formato que algumas pilhas
Rack/HTTP usam para cabeçalhos repetidos), o primeiro elemento é usado.

### `construct_event` → `Nfe::WebhookEvent`

Quando você quer não só validar, mas também desempacotar o evento, use
`construct_event`. Ele verifica primeiro; em caso de falha de assinatura **ou**
de JSON inválido, levanta `Nfe::SignatureVerificationError`.

```ruby
event = Nfe::Webhook.construct_event(
  payload: raw_body,
  signature: signature_header,
  secret: ENV.fetch("NFE_WEBHOOK_SECRET")
)

event.type       # ex.: "invoice.issued"
event.data       # Hash com o payload (a chave "payload" ou "data" do envelope)
event.id         # id estável para deduplicação, ou nil
event.created_at # timestamp da entrega como String, ou nil
```

`Nfe::WebhookEvent` é um objeto de valor imutável (`Data.define`). O `type` é
desempacotado da chave `action`/`event`/`type`/`event_type` do envelope, e o
`data` da chave `payload`/`data`.

## Leia o corpo CRU antes de parsear o JSON

A NFE.io assina os bytes que entregou. Leia o corpo cru **antes** de qualquer
parsing de JSON e passe esses bytes ao verificador.

:::warning Não re-serialize o payload
Nunca passe um objeto já parseado e re-serializado (por exemplo
`payload.to_json`). A ordem das chaves e os espaços em branco vão diferir dos
bytes assinados, e a verificação falhará de forma imprevisível. Sempre use o
corpo cru — `request.raw_post` ou `request.body.read`.
:::

## Exemplo: controller Rails

```ruby
class NfeWebhooksController < ActionController::Base
  # Webhooks não têm token CSRF.
  skip_before_action :verify_authenticity_token

  def create
    raw = request.raw_post
    signature = request.headers["X-Hub-Signature"]
    secret = ENV.fetch("NFE_WEBHOOK_SECRET")

    unless Nfe::Webhook.verify_signature(payload: raw, signature: signature, secret: secret)
      head :unauthorized
      return
    end

    event = Nfe::Webhook.construct_event(payload: raw, signature: signature, secret: secret)
    process_event(event) # idempotente — veja abaixo
    head :ok
  rescue Nfe::SignatureVerificationError
    head :unauthorized
  end

  private

  def process_event(event)
    # Dedupe pelo id do evento/nota antes de aplicar efeitos colaterais.
    return if already_handled?(event.id)

    mark_handled(event.id)
    # ... reaja a event.type / event.data ...
  end
end
```

:::note Em Rack puro
O valor do cabeçalho está em `request.get_header("HTTP_X_HUB_SIGNATURE")` e o
corpo cru em `request.body.read` (rebobine com `request.body.rewind` se for ler
de novo depois).
:::

## Validade não é frescor — handlers devem ser idempotentes

A NFE.io **não** envia primitiva de anti-replay: as entregas trazem apenas o
HMAC-SHA1 sobre o corpo, sem timestamp e sem nonce. Uma assinatura válida prova
**autenticidade**, mas não **frescor** — uma entrega reproduzida (replay) carrega
uma assinatura perfeitamente válida.

:::warning Sempre dedupe
Trate seus handlers como **idempotentes** e faça **deduplicação pelo
`event.id`** (id do evento ou da nota). Processar a mesma entrega duas vezes não
pode gerar efeitos colaterais duplicados.
:::

## Próximos passos

- [Primeiros passos](./getting-started.md) — emissão e polling como alternativa ao push.
- [Paginação](./pagination.md) — percorra listas de notas.
- [Downloads](./downloads.md) — baixe PDF/XML das notas.
