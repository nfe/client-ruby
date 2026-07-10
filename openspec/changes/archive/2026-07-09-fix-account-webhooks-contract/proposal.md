# Proposal: fix-account-webhooks-contract

## Why

O CRUD de webhooks do SDK Ruby está **100% quebrado contra a API real** — o contrato foi herdado por "parity with Node" de um contrato que o SDK Node havia **alucinado** (nunca existiu na API, nos specs, nem no SDK legado). Evidência de 3 sondas ao vivo contra `api.nfe.io` (2026-07-02/03, três contas — transcript completo em `client-nodejs/openspec/changes/fix-account-webhooks-contract/design.md`):

1. Todas as rotas company-scoped `/v1/companies/{id}/webhooks` retornam **404** (as 6 operações de `Nfe::Resources::Webhooks`).
2. O contrato real é account-scoped: `/v2/webhooks`, com envelope `{ "webHook": {...} }` obrigatório no request de create/update (sem ele: `400 "missing required properties: 'webHook'"`) e respostas também envelopadas.
3. O shape real é `{ id, uri, contentType, secret, filters, insecureSsl, headers, properties, status, createdOn, modifiedOn }` — o `Nfe::WebhookSubscription` atual (`url`/`events`/`active`) é rejeitado (`400 "The Uri field is required"`).
4. Os event types reais são `service_invoice.*`/`product_invoice.*`/`consumer_invoice.*` — os literais `invoice.*` de `AVAILABLE_EVENTS` não existem.
5. `PUT /v2/webhooks/{id}` é **substituição integral**: update sem `status` desativa o webhook (observado ao vivo).

Detalhe agravante: a change arquivada `add-entity-resources` **sondou `api.nfse.io/v2/webhooks` ao vivo** para confirmar o esquema de assinatura HMAC — o endpoint certo estava documentado no próprio repo e o management foi shipado company-scoped mesmo assim, por paridade. O contrato correto está em `openapi/nf-servico-v1.yaml`, `nf-produto-v2.yaml` e `nf-consumidor-v2.yaml` deste repo.

## What Changes

- Adicionar operações account-scoped a `Nfe::Resources::Webhooks`: `list_account_webhooks`, `create_account_webhook`, `retrieve_account_webhook`, `update_account_webhook`, `delete_account_webhook`, `delete_all_account_webhooks` (destrutivo, nome distinto), `ping_account_webhook`, `fetch_event_types` — todas sobre `/v2/webhooks`, com envelope `webHook` no request (create/update) e unwrap das respostas (fallback defensivo).
- Novo value object `Nfe::AccountWebhook` (`Data.define`) com o shape real, mapeando camelCase→snake_case no `from_api`. Nota de contrato: o spec declara `contentType`/`status` como enums inteiros, mas a API serializa strings (`"json"`, `"Active"`) — o DTO segue o fio real.
- Marcar `list/create/retrieve/update/delete/test` company-scoped, `get_available_events` e `Nfe::WebhookSubscription` como `@deprecated` (YARD; rota 404 na API atual; apontar equivalente account). Sem mudança de comportamento; remoção na próxima major.
- Documentar (YARD): create verifica a URI com ping (exige 2xx); `secret` 32–64 chars (ecoado no create, omitido nas leituras); `PUT` é substituição integral (enviar objeto completo, partir do retrieve).
- Teste de alinhamento (RSpec) amarrando os campos do `AccountWebhook` ao schema de `/v2/webhooks` em `openapi/nf-servico-v1.yaml` — sync de spec que mude o contrato quebra a suíte em vez de driftar.
- Atualizar RBS (`sig/nfe/resources/webhooks.rbs` + sig novo do DTO), docs (`docs/webhooks.md` e recurso), samples e a skill do SDK Ruby.
- Revisar a cláusula "SHALL match the Node SDK 1:1" do spec: paridade de superfície continua desejável, mas **contrato vem de spec OpenAPI + sonda ao vivo, nunca de SDK irmão** (foi assim que a alucinação virou 3 SDKs quebrados).

## Capabilities

### New Capabilities

_(nenhuma)_

### Modified Capabilities

- `entity-resources`: o requisito "Webhooks resource with CRUD, test, and available events" é reescrito — (1) webhooks passam a ser account-scoped com envelope `webHook` nos dois sentidos; (2) DTO `Nfe::AccountWebhook` com shape real; (3) métodos company-scoped deprecated (404 em 3 contas); (4) event types vivos via `fetch_event_types`; (5) fonte de contrato passa a ser o spec OpenAPI + sonda ao vivo.

## Impact

- **Código**: `lib/nfe/resources/webhooks.rb` (métodos novos + deprecations), `lib/nfe/resources/dto/account_webhook.rb` (novo), `lib/nfe/resources/dto/webhook.rb` (@deprecated), `sig/nfe/**` (RBS).
- **Atenção arquitetural**: o resource resolve `api_family :main` com `/v1` — os métodos account precisam atingir `/v2/webhooks` (decisão de mecânica no design).
- **Testes**: RSpec para envelope nos dois sentidos (fixtures do transcript real), alinhamento YAML↔DTO, testes company-scoped mantidos.
- **SemVer**: minor — métodos novos + deprecations; nada que funciona hoje muda (o CRUD atual já retorna 404 incondicional).
- **Sem quebra**: `Nfe::Webhook` (verificação de assinatura HMAC-SHA1, "nasceu certo") não é tocado.
