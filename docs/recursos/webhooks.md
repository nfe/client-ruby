---
title: Webhooks no SDK Ruby da NFE.io
sidebar_label: Webhooks
sidebar_position: 10
slug: webhooks
description: CRUD de webhooks no escopo da conta (/v2/webhooks), ping de teste, tipos de eventos ao vivo e verificação de assinatura no SDK Ruby da NFE.io.
---

# Webhooks

O recurso `webhooks` gerencia os webhooks **no escopo da conta autenticada**,
sob `/v2/webhooks` em `api.nfe.io` (família `main`, `api_key`). A API envelopa
os requests de create/update e as respostas de objeto único em `webHook` — o
SDK envelopa e desembrulha automaticamente. Além do CRUD, expõe um ping de
teste, a lista **ao vivo** de tipos de eventos e a verificação de assinatura.

:::warning Métodos por empresa estão deprecated
Os métodos company-scoped (`list`, `create`, `retrieve`, `update`, `delete`,
`test` sob `/v1/companies/{id}/webhooks`) estão **deprecated**: a rota retorna
**404** na API atual (confirmado em três contas, 2026-07-02/03). Use os
equivalentes `*_account_webhook*` abaixo. A remoção fica para a próxima major.
:::

## Métodos públicos

```ruby
webhooks.list_account_webhooks                     # => Nfe::ListResponse
webhooks.create_account_webhook(data)              # => Nfe::AccountWebhook
webhooks.retrieve_account_webhook(webhook_id)      # => Nfe::AccountWebhook
webhooks.update_account_webhook(webhook_id, data)  # => Nfe::AccountWebhook
webhooks.delete_account_webhook(webhook_id)        # => nil
webhooks.delete_all_account_webhooks               # => nil  (⚠️ apaga TODOS)
webhooks.ping_account_webhook(webhook_id)          # => nil
webhooks.fetch_event_types                         # => Array<String>
webhooks.verify_signature(payload:, signature:, secret:) # => Boolean
```

`Nfe::AccountWebhook` é um `Data.define` imutável com o shape real do fio:
`id`, `uri`, `content_type`, `secret`, `filters`, `insecure_ssl`, `headers`,
`properties`, `status`, `created_on`, `modified_on`. O `secret` (32–64
caracteres) é ecoado **apenas no create** e omitido nas leituras.

## Exemplos

### Criar um webhook

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))

hook = client.webhooks.create_account_webhook(
  uri: "https://app.exemplo.com.br/webhooks/nfe",
  contentType: "json",
  secret: ENV.fetch("NFE_WEBHOOK_SECRET"),   # 32–64 caracteres
  filters: ["service_invoice.issued_successfully", "service_invoice.issued_error"],
  status: "Active"
)

hook.id     # GUID do webhook
hook.secret # ecoado só aqui — guarde-o agora
```

:::warning A NFE.io pinga a URI na criação
No `create`, a NFE.io faz um **ping de verificação na `uri` e exige resposta
2xx** — o endpoint precisa estar no ar **antes** de criar o webhook, ou a
criação falha.
:::

### Descobrir os tipos de eventos (ao vivo)

```ruby
client.webhooks.fetch_event_types
# => ["service_invoice.issued_successfully", "service_invoice.cancelled_error",
#     "product_invoice.issued", "consumer_invoice.issued", ...]  (46 ids)
```

Os ids seguem o padrão `service_invoice.*` / `product_invoice.*` /
`consumer_invoice.*` e são os valores válidos para `filters`. Os literais
antigos `invoice.*` (de `get_available_events`, deprecated) **não existem** na
API real.

### Atualizar — o PUT é substituição integral

```ruby
current = client.webhooks.retrieve_account_webhook(hook.id)

client.webhooks.update_account_webhook(hook.id, {
  uri: current.uri,
  contentType: current.content_type,
  status: current.status,                       # sem isso o hook é DESATIVADO
  filters: ["service_invoice.issued_successfully"]
})
```

:::warning Campos omitidos voltam ao padrão
`PUT /v2/webhooks/{id}` **substitui o objeto inteiro** (confirmado ao vivo):
um update sem `status` desativa o webhook. Sempre parta do `retrieve` e envie
o objeto completo.
:::

### Testar, deletar

```ruby
client.webhooks.ping_account_webhook(hook.id)   # entrega de teste (204)
client.webhooks.delete_account_webhook(hook.id) # remove um webhook

# ⚠️ DESTRUTIVO: remove TODOS os webhooks da conta — método propositalmente
# distinto do delete unitário:
client.webhooks.delete_all_account_webhooks
```

### Verificar a assinatura de um payload recebido

```ruby
ok = client.webhooks.verify_signature(
  payload: request.raw_post,
  signature: request.get_header("HTTP_X_HUB_SIGNATURE"),
  secret: ENV.fetch("NFE_WEBHOOK_SECRET")
)

head :unauthorized unless ok
```

:::tip Use o módulo `Nfe::Webhook` no handler
`webhooks.verify_signature` é uma delegação fina para `Nfe::Webhook.verify_signature`.
No seu controlador HTTP, prefira chamar o módulo diretamente — ele não exige um
`Nfe::Client` e **nunca** levanta exceção, apenas devolve `true`/`false`. Veja o
guia de [Webhooks](../webhooks.md).
:::

:::note Fonte do contrato
O contrato acima vem do spec OpenAPI (`openapi/nf-servico-v1.yaml`) validado
por sonda ao vivo contra `api.nfe.io`, e está amarrado por um teste de
alinhamento na suíte — nunca de outro SDK. Única divergência deliberada: o
spec declara `contentType`/`status` como enums inteiros, mas a API serializa
strings (`"json"`, `"Active"`); o SDK segue o fio real.
:::

## Veja também

- [Webhooks (guia)](../webhooks.md) — verificação de assinatura e recebimento por push.
- [Emissão assíncrona e polling](../async-and-polling.md) — alternativa por polling.
