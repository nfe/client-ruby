# Design: fix-account-webhooks-contract (client-ruby)

## Context

`Nfe::Resources::Webhooks` implementa 6 operações company-scoped sobre `/v1/companies/{id}/webhooks` — todas retornam 404 na API real. O contrato veio por "parity with Node" (comentário no próprio código), e o Node o havia alucinado no rewrite (arqueologia completa em `client-nodejs/openspec/changes/fix-account-webhooks-contract/design.md`). O SDK Ruby não tem NENHUM método account-scoped. Ironia registrada: a change `add-entity-resources` sondou `api.nfse.io/v2/webhooks` ao vivo (para o esquema HMAC) e mesmo assim o management shipou company-scoped.

### Contrato confirmado ao vivo (3 sondas, 3 contas, 2026-07-02/03)

```
GET  /v1/companies/{id}/webhooks              -> 404 (todas as contas)
POST /v1/companies/{id}/webhooks              -> 404

GET  /v2/webhooks                             -> 200 { "webHooks": [ {...} ] }
GET  /v2/webhooks/{id}                        -> 200 { "webHook": {...} }  (secret OMITIDO)
GET  /v2/webhooks/eventTypes                  -> 200 { "eventTypes": [ { id, ... } ] }

POST /v2/webhooks  (body cru)                 -> 400 "missing required properties: 'webHook'"
POST /v2/webhooks  { "webHook": {...} }       -> 201 { "webHook": { id, uri, secret, contentType,
                                                        insecureSsl, status, filters, createdOn, modifiedOn } }
                                                 (secret ECOADO no create; NFE.io PINGA a uri e exige 2xx)

PUT  /v2/webhooks/{id}  (body cru)            -> 400 errors.WebHook = "The WebHook field is required."
PUT  /v2/webhooks/{id}  { "webHook": {...} }  -> 200 { "webHook": {...} }
                                                 ⚠️ SUBSTITUIÇÃO INTEGRAL: campos omitidos voltam ao
                                                 padrão — sem `status`, o hook volta a "Inactive"
PUT  /v2/webhooks/{id}/pings                  -> 204
DELETE /v2/webhooks/{id}                      -> 204
```

Event types reais (46 ids ao vivo): `service_invoice.issued_successfully`, `service_invoice.cancelled_error`, `product_invoice.*`, `consumer_invoice.*`, etc. Os `invoice.*` de `AVAILABLE_EVENTS` não existem.

O contrato correto já está em `openapi/nf-servico-v1.yaml` (e nf-produto-v2/nf-consumidor-v2). Única divergência spec vs. vivo: `contentType`/`status` declarados como enum int (0/1), serializados como string (`"json"`, `"Active"`).

## Goals / Non-Goals

**Goals:**
- CRUD de webhooks funcionando contra a API real (account-scoped, envelope nos dois sentidos), em idioma Ruby (snake_case, `Data.define`, keyword args onde couber).
- `Nfe::AccountWebhook` com shape real + RBS; deprecations YARD honestas nos company-scoped.
- Teste de alinhamento YAML↔DTO para impedir novo drift manuscrito.

**Non-Goals:**
- Remover métodos company-scoped (próxima major).
- Regenerar codegen para incluir webhook paths (o gerado atual não os emite; alinhamento via parse do YAML basta).
- Mexer em `Nfe::Webhook` (assinatura HMAC — correto desde o início).

## Decisions

### D1 — Métodos account no MESMO resource, com path v2 explícito
`Nfe::Resources::Webhooks` resolve `:main` com `/v1`. Os métodos account precisam de `/v2/webhooks` no mesmo host — mecânica concreta a validar no apply (path versionado explícito nos helpers get/post/put/delete, ou override de `api_version` por chamada, conforme o `AbstractResource` permitir). Espelha o Node (mesmo resource, client de conta).
*Alternativa rejeitada*: resource separado — quebra a descoberta `client.webhooks.*`.

### D2 — Envelope tratado no resource
`create_account_webhook`/`update_account_webhook` enviam `{ webHook: data }` (chave camelCase no fio); create/retrieve/update fazem unwrap `payload["webHook"] || payload` (fallback defensivo). Transporte HTTP fica genérico.

### D3 — DTO novo `Nfe::AccountWebhook`; `WebhookSubscription` intocado e deprecated
```ruby
class AccountWebhook < Data.define(
  :id, :uri, :content_type, :secret, :filters,
  :insecure_ssl, :headers, :properties, :status,
  :created_on, :modified_on
)
  # from_api: camelCase -> snake_case, nil-tolerante (padrão dos DTOs do repo)
end
```
`content_type`/`status` como String (fio real: `"json"`, `"Active"`), não int. `secret` opcional (ecoado só no create).
*Compat*: ninguém usa os métodos atuais com sucesso (404 incondicional) — DTO novo só nos métodos novos, zero quebra.

### D4 — Event types vivos
`fetch_event_types` (GET `/v2/webhooks/eventTypes`, extrai `id`s, retorna `Array<String>`). `AVAILABLE_EVENTS`/`get_available_events` viram `@deprecated` YARD apontando para ele.

### D5 — Alinhamento via parse do YAML no RSpec
Teste que carrega `openapi/nf-servico-v1.yaml` (Psych, stdlib) e compara: (a) chave `webHook` no requestBody do POST `/v2/webhooks`; (b) campos do schema ⊆ membros do `Data.define` (via mapa camelCase→snake_case); (c) PINA o enum int de `contentType`/`status` — se o spec for corrigido para string, o teste avisa para remover o desvio.

### D6 — Fonte de contrato
A cláusula "match the Node SDK 1:1" do spec é requalificada no delta: paridade de **superfície** (nomes/ergonomia), nunca de **contrato** — contrato vem de spec OpenAPI + sonda ao vivo. Comentários "(parity with Node)" junto a valores de contrato são removidos.

## Risks / Trade-offs

- [Mecânica do path v2 depende do `AbstractResource`] → Validar no início do apply; ajuste interno pequeno se necessário.
- [PUT integral pode surpreender] → YARD destacado + exemplo partindo do retrieve (espelha Node/PHP).
- [RBS pode divergir do runtime] → `rbs validate`/steep na CI já cobre (verificar no apply).

## Migration Plan

1. Implementar DTO + métodos + deprecations + RBS (uma PR); smoke ao vivo opcional reutilizando a sonda do client-nodejs.
2. Release **minor** com CHANGELOG destacando: CRUD company-scoped morto (deprecated), fluxo novo account-scoped.
3. Coordenar com client-nodejs (v5.1.0, já implementado) e client-php (change espelhada) para mensagens consistentes nos três CHANGELOGs.

## Open Questions

_(nenhuma — as três sondas do client-nodejs fecharam envelope no GET/{id}, PUT e pings; ver transcript acima)_
