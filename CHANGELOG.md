# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

> Duas correções de contrato contra a API real: o CRUD de webhooks (provado por
> sonda ao vivo, 2026-07-02/03, três contas) e a cobertura do retrieve de NFS-e
> (o DTO descartava mais da metade dos campos). Em ambas, o contrato correto
> sempre esteve nos specs oficiais (`openapi/nf-servico-v1.yaml` e equivalentes) —
> o código manuscrito havia divergido deles.

### Corrigido

- **O CRUD de webhooks funcionava 0% das vezes**: a rota company-scoped
  `/v1/companies/{id}/webhooks` retorna 404 na API atual. O contrato real é
  account-scoped (`/v2/webhooks`) e exige o request envelopado em
  `{ "webHook": {...} }` (sem ele responde
  `400 "missing required properties: 'webHook'"`), devolvendo a resposta também
  envelopada. Os novos métodos account-scoped envelopam o request
  (create/update) e desembrulham as respostas (create/retrieve/update/list),
  com fallback defensivo para corpo cru.
- **`Nfe::ServiceInvoice` descartava ~25 dos 44 campos do retrieve de NFS-e**
  (toda a árvore de retenções, `provider`, `taxationType`, `location`,
  `approximateTax`, ...): o `from_api` agora preserva o payload completo em
  `invoice.raw` (padrão do `ConsumerInvoice`), em todas as leituras
  (list/retrieve/cancel/201-issued).

### Adicionado

- Métodos account-scoped em `client.webhooks`: `list_account_webhooks`,
  `create_account_webhook`, `retrieve_account_webhook`,
  `update_account_webhook`, `delete_account_webhook`,
  `delete_all_account_webhooks` (destrutivo, nome propositalmente distinto),
  `ping_account_webhook` e `fetch_event_types`.
- Value object **`Nfe::AccountWebhook`** (`Data.define`, com RBS) com o shape
  real da API: `uri`, `content_type`, `secret` (32–64 caracteres, ecoado no
  create e omitido nas leituras), `filters`, `insecure_ssl`, `headers`,
  `properties`, `status`, `created_on`, `modified_on`. Nota: o spec declara
  `contentType`/`status` como enums inteiros, mas a API serializa strings
  (`"json"`, `"Active"`) — o DTO segue o fio real.
- `fetch_event_types` retorna os event types reais de
  `GET /v2/webhooks/eventTypes` (46 ids ao vivo, padrão
  `service_invoice.*`/`product_invoice.*`/`consumer_invoice.*`).
- Teste de alinhamento (RSpec + Psych) amarrando o `Nfe::AccountWebhook` ao
  schema de `/v2/webhooks` em `openapi/nf-servico-v1.yaml` — um sync de spec
  que mude o contrato de webhooks quebra a suíte em vez de driftar.
- YARD do `create_account_webhook` documenta a verificação de URI na criação
  (a NFE.io faz um ping e exige resposta 2xx) e o `secret` de 32–64 caracteres.
- YARD do `update_account_webhook` documenta que o `PUT` é substituição
  integral (confirmado ao vivo em 2026-07-03): campos omitidos voltam ao
  padrão — update sem `status` **desativa o webhook**. Envie o objeto completo
  (parta do retrieve).
- Campos de ISS tipados em `Nfe::ServiceInvoice`: `base_tax_amount`,
  `iss_rate`, `iss_tax_amount`.
- Value object **`Nfe::ServiceInvoiceBorrower`** (tomador, com RBS):
  `federal_tax_number` sempre `String` (tolerante ao CNPJ alfanumérico da
  IN RFB 2.229/2024, fio Integer ou String) e **ponte Hash** — leituras
  `borrower["..."]`/`borrower.dig(...)` continuam funcionando (delegam ao
  payload cru), agora ao lado dos leitores tipados.
- Teste de alinhamento (RSpec + Psych) amarrando `Nfe::ServiceInvoice` ao
  schema inline do retrieve em `openapi/nf-servico-v1.yaml`, **ancorado por
  path** (há colisão de `operationId` no spec) — também serve de gatilho de
  migração: quando a resposta for componentizada upstream, o teste falha e
  sinaliza migrar para o modelo gerado.
- Spec `nf-servico-v1.yaml` atualizado (respostas de erro tipadas com
  `ErrorsResource` em `components.schemas`) + namespace gerado
  `Nfe::Generated::NfServicoV1` (somente o modelo de erros; a resposta de
  sucesso segue inline e o DTO manuscrito).

### Deprecado

- Métodos company-scoped de webhooks (`list`, `create`, `retrieve`, `update`,
  `delete`, `test` sobre `/v1/companies/{id}/webhooks`): a rota retorna **404**
  na API atual (confirmado em três contas, 2026-07-02/03). Use os equivalentes
  account-scoped. O comportamento não mudou; remoção fica para a próxima major.
- `Nfe::WebhookSubscription` (`url`/`events`/`active`) e
  `get_available_events`/`AVAILABLE_EVENTS` (literais `invoice.*`): shapes e
  eventos que a API real rejeita ou desconhece. Use `Nfe::AccountWebhook` e
  `fetch_event_types`.
- `Nfe::ServiceInvoice#pdf` e `#xml`: campos-fantasma — a resposta do retrieve
  não os traz (sempre `nil`). Use `download_pdf`/`download_xml`. Remoção na
  próxima major.

## [1.0.0] - 2026-07-02

### Adicionado

- `Nfe::Client.new(api_key:)` — entrypoint por instância (estilo Stripe), com fallback de
  credencial via `ENV["NFE_API_KEY"]` / `ENV["NFE_DATA_API_KEY"]` (o argumento explícito vence).
- 19 acessores de recurso `snake_case` e lazy — 17 canônicos (`service_invoices`,
  `product_invoices`, `consumer_invoices`, `transportation_invoices`,
  `inbound_product_invoices`, `product_invoice_query`, `consumer_invoice_query`, `companies`,
  `legal_people`, `natural_people`, `webhooks`, `addresses`, `legal_entity_lookup`,
  `natural_person_lookup`, `tax_calculation`, `tax_codes`, `state_taxes`) mais 2 RTC
  (`service_invoices_rtc`, `product_invoices_rtc`).
- Modelos imutáveis `Data.define` gerados a partir das specs OpenAPI, com assinaturas RBS
  (`sig/**/*.rbs`) verificáveis pelo Steep e empacotadas na gem para type-check no consumidor.
- Contrato assíncrono 202 discriminado: `create` retorna um `*Pending`
  (`pending? -> true`/`issued? -> false`) ou um `*Issued` (`issued? -> true`); polling via
  `retrieve` até `Nfe::FlowStatus.terminal?(flow_status)`.
- Emissão RTC com tributos IBS/CBS/IS (`service_invoices_rtc`, `product_invoices_rtc`).
- Verificação de webhook HMAC-SHA1 sobre os bytes crus da requisição
  (`Nfe::Webhook.verify_signature`, comparação timing-safe, nunca levanta exceção) e
  `Nfe::Webhook.construct_event`.
- Roteamento multi-host automático por recurso (`api.nfe.io`, `api.nfse.io`,
  `address.api.nfe.io`, `legalentity.api.nfe.io`, `naturalperson.api.nfe.io`, `nfe.api.nfe.io`).
- Retry com backoff configurável (`max_retries`) para falhas transitórias.
- Downloads binários (String `ASCII-8BIT`) para a maioria dos recursos; exceção:
  `product_invoices` e `product_invoices_rtc` retornam `Nfe::NfeFileResource` (value object `{uri}`).
- `Nfe::DateNormalizer` para normalização consistente de datas.
- Modelo de duas chaves (`api_key` + `data_api_key`) com seleção automática por família de recurso.

### Alterado

- Namespace unificado em `Nfe`.
- Piso de Ruby elevado para **3.2+**.
- Paginação suporta os dois estilos da API: por página (`service_invoices`) e por cursor
  (`product`/`consumer`/`state_taxes`), via `Nfe::ListResponse`/`Nfe::ListPage`.
- Configuração migrada da API global para `Nfe::Client` por instância — ver `MIGRATION.md`.

### Removido

- Dependência de runtime `rest-client`.
- Configuração global `Nfe.api_key`.
- Classes achatadas da série `0.3.x` (ex.: `Nfe::ServiceInvoice.company_id(...).create`),
  preservadas no branch `0.x-legacy`.

## [0.3.2]

- Última versão da série `0.x` (legada, baseada em `rest-client`). Congelada, sem manutenção.

[Não lançado]: https://github.com/nfe/client-ruby/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/nfe/client-ruby/compare/v0.3.2...v1.0.0
[0.3.2]: https://github.com/nfe/client-ruby/releases/tag/v0.3.2
