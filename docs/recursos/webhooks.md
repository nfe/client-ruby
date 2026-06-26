---
title: Webhooks no SDK Ruby da NFE.io
sidebar_label: Webhooks
sidebar_position: 10
slug: webhooks
description: CRUD de assinaturas de webhook por empresa, disparo de teste, lista de eventos disponíveis e verificação de assinatura no SDK Ruby da NFE.io.
---

# Webhooks

O recurso `webhooks` gerencia as assinaturas de webhook **escopadas por empresa**,
sob `/companies/{id}/webhooks`. Faz parte da família `main`, servida por
`api.nfe.io` (`/v1`), e usa a `api_key`. Além do CRUD, expõe um disparo de teste,
a lista estática de eventos e a verificação de assinatura.

## Métodos públicos

```ruby
webhooks.list(company_id)                          # => Nfe::ListResponse
webhooks.create(company_id, data)                  # => Nfe::WebhookSubscription
webhooks.retrieve(company_id, webhook_id)          # => Nfe::WebhookSubscription
webhooks.update(company_id, webhook_id, data)      # => Nfe::WebhookSubscription
webhooks.delete(company_id, webhook_id)            # => nil
webhooks.test(company_id, webhook_id)              # => { success: bool, message: String? }
webhooks.get_available_events                      # => Array<String>
webhooks.verify_signature(payload:, signature:, secret:) # => Boolean
```

Os eventos disponíveis (`get_available_events`) são:
`invoice.issued`, `invoice.cancelled`, `invoice.failed`, `invoice.processing`,
`company.created`, `company.updated` e `company.deleted`.

## Exemplos

### Criar e testar uma assinatura

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))
company_id = "55df4dc6b6cd9007e4f13ee8"

hook = client.webhooks.create(
  company_id,
  url: "https://app.exemplo.com.br/webhooks/nfe",
  events: ["invoice.issued", "invoice.failed"],
  secret: ENV.fetch("NFE_WEBHOOK_SECRET"),
  active: true
)

# Dispara uma entrega sintética para validar que o endpoint responde:
result = client.webhooks.test(company_id, hook.id)
result[:success]
```

### Verificar a assinatura de um payload recebido

```ruby
ok = client.webhooks.verify_signature(
  payload: request.raw_post,
  signature: request.get_header("HTTP_X_NFE_SIGNATURE"),
  secret: ENV.fetch("NFE_WEBHOOK_SECRET")
)

head :unauthorized unless ok
```

:::tip Use o módulo `Nfe::Webhook` no handler
`webhooks.verify_signature` é uma delegação fina para `Nfe::Webhook.verify_signature`,
oferecida por paridade com o SDK Node. No seu controlador HTTP, prefira chamar o
módulo diretamente — ele não exige um `Nfe::Client` e **nunca** levanta exceção,
apenas devolve `true`/`false`. Veja o guia de [Webhooks](../webhooks.md).
:::

:::note `list` tolera vários formatos
`list(company_id)` aceita a resposta da API como array puro, embrulhada em `data`
ou em um envelope `webhooks`, sempre devolvendo um `Nfe::ListResponse`.
:::

## Veja também

- [Webhooks (guia)](../webhooks.md) — verificação de assinatura e recebimento por push.
- [Empresas](./companies.md) — o escopo (`company_id`) das assinaturas.
- [Emissão assíncrona e polling](../async-and-polling.md) — alternativa por polling.
