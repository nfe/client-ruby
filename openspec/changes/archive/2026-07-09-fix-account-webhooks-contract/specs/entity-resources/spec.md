# entity-resources — Delta (fix-account-webhooks-contract)

> Contexto: 3 sondas ao vivo contra `api.nfe.io` (2026-07-02/03, 3 contas) provaram que
> `/v1/companies/{id}/webhooks` retorna 404 e que o contrato real é `/v2/webhooks`
> (escopo conta) com envelope `{ "webHook": {...} }` nos dois sentidos. O contrato
> anterior foi herdado por "parity with Node" de uma alucinação. Transcript em `../../design.md`.

## MODIFIED Requirements

### Requirement: Webhooks resource with CRUD, test, and available events
`Nfe::Resources::Webhooks` SHALL manage webhooks at the **account** level over `/v2/webhooks`, honoring the live API contract: create/update requests MUST be wrapped in a `webHook` envelope, and enveloped responses MUST be unwrapped before returning. The account-scoped surface is `list_account_webhooks`, `create_account_webhook`, `retrieve_account_webhook`, `update_account_webhook`, `delete_account_webhook`, `delete_all_account_webhooks` (distinctly-named destructive bulk delete), `ping_account_webhook`, and `fetch_event_types` (live event type list). The legacy company-scoped methods (`list`, `create`, `retrieve`, `update`, `delete`, `test`) and the hardcoded `get_available_events` SHALL remain with unchanged behavior but be marked `@deprecated` (YARD) — the `/v1/companies/{id}/webhooks` route returns 404 on the current API (confirmed on three accounts, 2026-07-02/03). Surface parity with the Node SDK remains desirable for names/ergonomics, but the contract source of truth is the OpenAPI spec (`openapi/nf-servico-v1.yaml`) plus live probes — NEVER a sibling SDK.

#### Scenario: Account webhook create with envelope (live-confirmed)
- **WHEN** `client.webhooks.create_account_webhook({ uri: "...", content_type: "json", secret: <32–64 chars>, filters: ["service_invoice.issued_successfully"] })` is called
- **THEN** the SDK SHALL POST `/v2/webhooks` with body `{"webHook": {...}}` (the API rejects a bare body with `400 "missing required properties: 'webHook'"`)
- **AND** SHALL unwrap the `201 {"webHook": {...}}` response into an `Nfe::AccountWebhook` with `id` populated
- **AND** the YARD doc SHALL state that NFE.io pings the `uri` at creation time and requires a 2xx response

#### Scenario: List, retrieve, update, delete, ping
- **WHEN** the consumer lists / retrieves / updates / deletes / pings account webhooks
- **THEN** the SDK SHALL issue `GET /v2/webhooks` (unwrapping `{webHooks: [...]}`), `GET /v2/webhooks/{id}`, `PUT /v2/webhooks/{id}` (request wrapped in `webHook`), `DELETE /v2/webhooks/{id}`, and `PUT /v2/webhooks/{id}/pings`
- **AND** single-object responses SHALL be unwrapped from `{webHook: {...}}` with a defensive raw-body fallback
- **AND** the update YARD doc SHALL warn that `PUT` is a full replacement — omitted fields reset to defaults; an update without `status` deactivates the webhook (live-confirmed)

#### Scenario: Bulk delete is a distinct, dangerous method
- **WHEN** `delete_all_account_webhooks` is exposed (`DELETE /v2/webhooks` removes ALL account webhooks)
- **THEN** it SHALL be a separately-named method unreachable by a mistyped single delete, documented as destructive

#### Scenario: Live event types
- **WHEN** `client.webhooks.fetch_event_types` is called
- **THEN** the SDK SHALL GET `/v2/webhooks/eventTypes` and return the live `Array<String>` of event ids (pattern `service_invoice.*`/`product_invoice.*`/`consumer_invoice.*` — the legacy `invoice.*` literals do not exist on the live API)
- **AND** `get_available_events` SHALL be `@deprecated` pointing to it

#### Scenario: Deprecated company-scoped methods stay intact
- **WHEN** the consumer calls `client.webhooks.list(company_id)` (or any company-scoped method)
- **THEN** the request still targets `/companies/{id}/webhooks` unchanged (no behavior change, no runtime warning)
- **AND** the `@deprecated` YARD doc names the account-scoped replacement and the 404 evidence

## ADDED Requirements

### Requirement: AccountWebhook value object mirrors the live resource shape
The SDK SHALL expose `Nfe::AccountWebhook` (`Data.define`) with the live fields — `id`, `uri`, `content_type`, `secret` (32–64 chars; echoed on create, omitted on reads), `filters`, `insecure_ssl`, `headers`, `properties`, `status`, `created_on`, `modified_on` — with `from_api` mapping the wire camelCase, used by all account-scoped methods, and covered by RBS signatures. The legacy `Nfe::WebhookSubscription` (`url`/`events`/`active`) SHALL remain and be `@deprecated` (its shape is rejected live with `400 "The Uri field is required"`). Wire-format note: the spec declares `contentType`/`status` as int enums but the API serializes strings (`"json"`, `"Active"`) — the DTO follows the wire.

#### Scenario: Alignment test pins the contract
- **WHEN** the RSpec suite runs
- **THEN** an alignment spec SHALL parse the `/v2/webhooks` schema from `openapi/nf-servico-v1.yaml` (Psych) and compare its fields against `Nfe::AccountWebhook`'s members (camelCase→snake_case map)
- **AND** SHALL pin the deliberate deviations (`contentType`/`status` string vs int enum) so a corrected spec sync fails the test as a signal to drop the deviation
