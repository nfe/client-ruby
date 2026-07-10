# Tasks: fix-account-webhooks-contract (client-ruby)

## 1. DTO

- [x] 1.1 Criar `lib/nfe/resources/dto/account_webhook.rb` (`Data.define`: `id`, `uri`, `content_type`, `secret`, `filters`, `insecure_ssl`, `headers`, `properties`, `status`, `created_on`, `modified_on`; `from_api` camelCase→snake_case, nil-tolerante)
- [x] 1.2 Marcar `Nfe::WebhookSubscription` como `@deprecated` (YARD) apontando `Nfe::AccountWebhook`
- [x] 1.3 RBS: `sig/nfe/account_webhook.rbs` (novo) + atualizar `sig/nfe/resources/webhooks.rbs`

## 2. Resource

- [x] 2.1 Resolver a mecânica do path v2 no host `main` (D1: path versionado explícito ou override de `api_version` — validar contra `AbstractResource`)
- [x] 2.2 `create_account_webhook`: body `{ webHook: data }`, unwrap `payload["webHook"] || payload`, retorna `AccountWebhook`
- [x] 2.3 `update_account_webhook`: mesmo envelope; YARD destacado do PUT integral (update sem `status` desativa o hook — exemplo partindo do retrieve)
- [x] 2.4 `retrieve_account_webhook` (unwrap + fallback), `list_account_webhooks` (unwrap `webHooks` → `ListResponse`), `delete_account_webhook`, `delete_all_account_webhooks` (nome distinto, doc destrutivo), `ping_account_webhook` (`PUT /{id}/pings`)
- [x] 2.5 `fetch_event_types` (GET `/v2/webhooks/eventTypes`, extrai ids); `get_available_events`/`AVAILABLE_EVENTS` `@deprecated`
- [x] 2.6 Marcar os 6 métodos company-scoped como `@deprecated` (404 em 3 contas, 2026-07-02/03; apontar equivalente account); comportamento inalterado
- [x] 2.7 YARD do create: ping de verificação da URI (exige 2xx) e `secret` 32–64 chars
- [x] 2.8 Remover comentários "(parity with Node)" junto a valores de contrato (fonte: spec OpenAPI + sonda ao vivo)

## 3. Alinhamento com o spec

- [x] 3.1 Spec RSpec de alinhamento: parse (Psych) do schema `/v2/webhooks` em `openapi/nf-servico-v1.yaml` vs membros do `AccountWebhook`
- [x] 3.2 Pinar no teste os desvios deliberados (`contentType`/`status` string no fio vs enum int no spec)

## 4. Testes

- [x] 4.1 Unit: create envia envelope e desembrulha 201 (fixture do transcript real das sondas)
- [x] 4.2 Unit: update envelopado + retrieve/list unwrap + fallback corpo cru
- [x] 4.3 Unit: `delete_all_account_webhooks` é método distinto do delete single
- [x] 4.4 Manter testes company-scoped (comportamento deprecated inalterado)
- [x] 4.5 `rbs validate`/steep limpos com os sigs novos
- [x] 4.6 (Opcional) Smoke ao vivo reutilizando a sonda do client-nodejs

## 5. Docs & release

- [x] 5.1 Atualizar `docs/webhooks.md` e o cookbook do recurso (fluxo account, eventos reais, callouts: ping 2xx na criação, PUT integral)
- [x] 5.2 Atualizar samples e a skill do SDK Ruby (nfeio-ruby-sdk) se citarem o fluxo company-scoped ou `invoice.*`
- [x] 5.3 CHANGELOG (minor): fix do CRUD de webhooks, deprecations, DTO novo — mensagens consistentes com client-nodejs v5.1.0 e client-php
