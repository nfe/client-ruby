# entity-resources Specification

## Purpose
TBD - created by archiving change add-entity-resources. Update Purpose after archive.
## Requirements
### Requirement: Four entity resources are fully implemented
The SDK SHALL implement four entity resource classes under `Nfe::Resources` — `Companies`, `LegalPeople`, `NaturalPeople`, and `Webhooks` — reachable through the lazy snake_case accessors `client.companies`, `client.legal_people`, `client.natural_people`, and `client.webhooks` on the `Nfe::Client` defined in `add-client-core`. All four resolve to the `main` host family (`base_url_for(:main)` → `https://api.nfe.io`, with the `/v1` segment supplied by the resource `api_version`, yielding effective URLs under `https://api.nfe.io/v1/...`) via `Nfe::Configuration#base_url_for(:main)`. Method names and behaviour SHALL match the NFE.io Node.js SDK 1:1, adapted to Ruby idioms (snake_case methods, keyword arguments, `Data.define` value objects, synchronous returns, raised typed errors).

#### Scenario: Resource availability on Client
- **WHEN** consumer code reads any of `client.companies`, `client.legal_people`, `client.natural_people`, `client.webhooks`
- **THEN** the accessor SHALL return a fully functional resource instance (not a stub raising `NoMethodError`)

#### Scenario: Entity resources route to the main host
- **WHEN** any method of any of the four entity resources issues an HTTP request
- **THEN** the request SHALL target the host `https://api.nfe.io` resolved through `Configuration#base_url_for(:main)`, with the `/v1` segment supplied by the resource `api_version` (effective URL `https://api.nfe.io/v1/...`) and no hard-coded host in the resource

#### Scenario: Parity with the Node SDK
- **WHEN** comparing method names, parameter order, and return-shape categories between this Ruby SDK and the Node SDK for any of the four entity resources
- **THEN** they SHALL be 1:1 equivalent modulo language idioms (snake_case, keyword args, `Data.define`, synchronous returns) and the additions and deferrals documented in this change's design.md

### Requirement: Companies CRUD with response unwrapping
`Nfe::Resources::Companies` SHALL expose `create`, `list`, `list_all`, `list_each`, `retrieve`, `update`, and `remove` against `/companies`. The NFE.io API wraps responses in `{"companies" => <object|array>}`; the resource SHALL transparently unwrap that envelope before hydrating a `Nfe::Company` value object.

#### Scenario: Create returns hydrated value object
- **WHEN** `create(data)` succeeds with the API responding `{"companies" => {"id" => "abc", "name" => "Acme"}}`
- **THEN** the method SHALL return a `Nfe::Company` whose `id` and other fields are populated

#### Scenario: List pagination converts 1-based to 0-based
- **WHEN** `list(page_count: 20, page_index: 0)` is called and the API responds `{"companies" => [...], "page" => 1}`
- **THEN** the method SHALL return a `Nfe::ListResponse` whose `page.page_index` is `0` (the API uses 1-based indexing and the resource converts to 0-based)

#### Scenario: list_all auto-paginates
- **WHEN** `list_all` is called against an account with 250 companies
- **THEN** the method SHALL issue multiple GET requests with `page_count: 100` until a page returns fewer than 100 items and SHALL return a single `Array` aggregating all pages

#### Scenario: list_each streams via an Enumerator
- **WHEN** `list_each` is called without a block
- **THEN** the method SHALL return an `Enumerator` that fetches pages on demand and yields one `Nfe::Company` at a time

#### Scenario: Remove returns deletion confirmation
- **WHEN** `remove(company_id)` succeeds
- **THEN** the method SHALL return `{ deleted: true, id: company_id }`

#### Scenario: Not found surfaces typed error
- **WHEN** `retrieve(company_id)` receives HTTP 404 from the API
- **THEN** the SDK SHALL raise `Nfe::NotFoundError`

### Requirement: Companies tax-number handling avoids numeric coercion
`Nfe::Resources::Companies#create` and `#update` SHALL validate the `federalTaxNumber` for format and length only (11 digits CPF or 14 digits CNPJ), normalised as a digit string. They SHALL NOT run check-digit validation client-side and SHALL NOT coerce the value to an `Integer`, so that alphanumeric CNPJ (IN RFB 2.229/2024, effective July 2026) is not corrupted.

#### Scenario: Tax number kept as string
- **WHEN** `create` is called with a 14-character alphanumeric CNPJ
- **THEN** the SDK SHALL accept it without converting to `Integer` and without rejecting it on a numeric-only check-digit rule

#### Scenario: Wrong-length tax number rejected
- **WHEN** `create` is called with a `federalTaxNumber` whose normalised digit length is neither 11 nor 14
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` before issuing an HTTP request

### Requirement: Companies search and finder helpers
`Nfe::Resources::Companies` SHALL expose `find_by_tax_number(tax_number)` returning a `Nfe::Company` or `nil`, and `find_by_name(name)` returning an `Array` of matching companies. Both are convenience helpers built on `list_all` plus client-side filtering and SHALL be documented as intended for small accounts.

#### Scenario: Find by tax number
- **WHEN** `find_by_tax_number("12345678901234")` is called and a company with that `federalTaxNumber` exists
- **THEN** the method SHALL return that `Nfe::Company`

#### Scenario: Find by name with no match
- **WHEN** `find_by_name("NonExistent Corp")` is called and no company matches
- **THEN** the method SHALL return an empty `Array`

#### Scenario: Empty search name rejected
- **WHEN** `find_by_name("")` or a whitespace-only name is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError`

### Requirement: Company certificate upload with real PKCS#12 validation
`Nfe::Resources::Companies` SHALL expose `upload_certificate(company_id, file:, password:, filename: nil)` and `replace_certificate(...)` (an alias) that POST a `multipart/form-data` body to `/companies/{id}/certificate` with the fields `file` (the .pfx/.p12 binary) and `password`. Before uploading, the SDK SHALL pre-validate the certificate locally via `validate_certificate`. The multipart body SHALL be built using Ruby stdlib (`Net::HTTP` form posting), introducing no new runtime dependency.

#### Scenario: Successful upload
- **WHEN** `upload_certificate(company_id, file: pfx_bytes, password: "secret", filename: "cert.pfx")` is called with a valid certificate and matching password
- **THEN** the SDK SHALL POST a multipart body carrying `file` and `password` to `/companies/{id}/certificate` and return `{ uploaded: true, message: <string?> }`

#### Scenario: Unsupported file extension rejected before upload
- **WHEN** `upload_certificate` is called with `filename: "cert.pem"`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` without issuing an HTTP request

#### Scenario: Replace is an alias of upload
- **WHEN** `replace_certificate(company_id, file:, password:)` is called
- **THEN** it SHALL behave identically to `upload_certificate` (the API handles replacement)

### Requirement: Local certificate validation via OpenSSL::PKCS12
`Nfe::Resources::Companies#validate_certificate(file:, password:)` SHALL perform a local-only validation (no HTTP) by parsing the PKCS#12 bytes with `OpenSSL::PKCS12.new(der_bytes, password)`. A wrong password or malformed DER SHALL raise `Nfe::InvalidRequestError`. On success it SHALL return a `Nfe::CertificateInfo` value object carrying `subject`, `issuer`, `not_before`, `not_after`, and `serial_number` extracted from the parsed certificate.

#### Scenario: Valid certificate and password
- **WHEN** `validate_certificate(file: pfx_bytes, password: "correct")` is called with a real PKCS#12 and the correct password
- **THEN** the method SHALL return a `Nfe::CertificateInfo` whose `not_after` is the certificate's actual expiry date (not a fabricated placeholder)

#### Scenario: Wrong password rejected
- **WHEN** `validate_certificate` is called with an incorrect password
- **THEN** `OpenSSL::PKCS12.new` SHALL raise, and the SDK SHALL surface a `Nfe::InvalidRequestError`

#### Scenario: No HTTP request is made
- **WHEN** `validate_certificate` runs
- **THEN** the SDK SHALL NOT issue any HTTP request

### Requirement: Certificate password and PKCS#12 bytes are handled in-memory only
The certificate password and PKCS#12 (.pfx/.p12) bytes SHALL be handled in-memory only. The SDK SHALL NOT persist either the password or the PKCS#12 bytes to disk (no temp files, no caches). Neither the password nor the PKCS#12 bytes SHALL appear in any log line, in any raised exception message, or in any `Nfe::Error` attribute (including `Error#to_h` / `Error#message`). The password `String` SHALL NOT be retained beyond the upload call where feasible (it SHALL NOT be stored on the resource instance or memoized).

#### Scenario: Password absent from logs
- **WHEN** `upload_certificate` or `validate_certificate` runs with debug/body logging enabled
- **THEN** no log line SHALL contain the password value or the PKCS#12 bytes (the multipart body SHALL NOT be logged)

#### Scenario: Password absent from any raised exception / Error#to_h
- **WHEN** `OpenSSL::PKCS12.new` raises (wrong password or malformed DER) and the SDK surfaces a `Nfe::InvalidRequestError`
- **THEN** the raised error's `message` and `to_h` SHALL NOT contain the password value or the raw PKCS#12 bytes

### Requirement: Company certificate status and expiry helpers
`Nfe::Resources::Companies` SHALL expose `get_certificate_status(company_id)` returning a `Nfe::CertificateStatus`, `check_certificate_expiration(company_id, threshold_days: 30)`, `get_companies_with_certificates`, and `get_companies_with_expiring_certificates(threshold_days: 30)`. Each SHALL query `GET /companies/{id}/certificate`. The `days_until_expiration` and `expiring_soon` fields SHALL be computed client-side from `expires_on`.

#### Scenario: Certificate status snapshot
- **WHEN** `get_certificate_status(company_id)` succeeds against `GET /companies/{id}/certificate`
- **THEN** the method SHALL return a `Nfe::CertificateStatus` carrying `has_certificate` (boolean), `expires_on` (string ISO date-time or nil), `valid` (boolean or nil), `days_until_expiration` (integer or nil, computed client-side from `expires_on`), `expiring_soon` (boolean or nil, computed client-side via threshold), and `details` (raw payload)

#### Scenario: Expiration check within threshold
- **WHEN** `check_certificate_expiration(company_id, threshold_days: 30)` is called and the certificate expires in 10 days
- **THEN** the method SHALL return `{ expiring: true, days_remaining: 10, expires_on: <date> }`

#### Scenario: Expiration check outside threshold
- **WHEN** the certificate expires in 200 days with `threshold_days: 30`
- **THEN** the method SHALL return `nil`

#### Scenario: Listing companies with expiring certificates
- **WHEN** `get_companies_with_expiring_certificates(30)` is called
- **THEN** the method SHALL list all companies, query certificate status for each (skipping companies whose status lookup fails), and return only those expiring within the threshold

### Requirement: LegalPeople and NaturalPeople resources are parallel
`Nfe::Resources::LegalPeople` and `Nfe::Resources::NaturalPeople` SHALL expose the same operations — `list`, `create`, `retrieve`, `update`, `delete`, `create_batch`, and `find_by_tax_number` — differing only in endpoint base path (`/companies/{id}/legalpeople` vs `/companies/{id}/naturalpeople`), response envelope key (`legalPeople` vs `naturalPeople`), and tax-number semantics (CNPJ 14 digits vs CPF 11 digits). `list` takes only a `company_id` (no pagination parameters, matching the Node SDK) and unwraps `{"<plural>" => [...]}`.

#### Scenario: Legal person create unwraps envelope
- **WHEN** `client.legal_people.create(company_id, data)` is called
- **THEN** the SDK SHALL POST `/companies/{company_id}/legalpeople`, unwrap the `legalPeople` envelope, and return a `Nfe::LegalPerson`

#### Scenario: Natural person tax number normalised
- **WHEN** `find_by_tax_number(company_id, "123.456.789-01")` is called on `NaturalPeople`
- **THEN** the SDK SHALL normalise the input to 11 digits and search by `federalTaxNumber`

#### Scenario: Batch creation is sequential
- **WHEN** `create_batch(company_id, [a, b, c])` is called
- **THEN** the SDK SHALL invoke `create` sequentially (no concurrency primitive) and return the three created entities in order

#### Scenario: Delete returns nil
- **WHEN** `delete(company_id, legal_person_id)` succeeds
- **THEN** the method SHALL return `nil`

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

### Requirement: AccountWebhook value object mirrors the live resource shape
The SDK SHALL expose `Nfe::AccountWebhook` (`Data.define`) with the live fields — `id`, `uri`, `content_type`, `secret` (32–64 chars; echoed on create, omitted on reads), `filters`, `insecure_ssl`, `headers`, `properties`, `status`, `created_on`, `modified_on` — with `from_api` mapping the wire camelCase, used by all account-scoped methods, and covered by RBS signatures. The legacy `Nfe::WebhookSubscription` (`url`/`events`/`active`) SHALL remain and be `@deprecated` (its shape is rejected live with `400 "The Uri field is required"`). Wire-format note: the spec declares `contentType`/`status` as int enums but the API serializes strings (`"json"`, `"Active"`) — the DTO follows the wire.

#### Scenario: Alignment test pins the contract
- **WHEN** the RSpec suite runs
- **THEN** an alignment spec SHALL parse the `/v2/webhooks` schema from `openapi/nf-servico-v1.yaml` (Psych) and compare its fields against `Nfe::AccountWebhook`'s members (camelCase→snake_case map)
- **AND** SHALL pin the deliberate deviations (`contentType`/`status` string vs int enum) so a corrected spec sync fails the test as a signal to drop the deviation

### Requirement: ID validators run before HTTP
Every entity resource method that takes an identifier (`company_id`, `legal_person_id`, `natural_person_id`, `webhook_id`) SHALL validate it through the shared ID validators from `add-client-core` before issuing the HTTP request, failing fast with a Portuguese-language message.

#### Scenario: Empty company ID rejected synchronously
- **WHEN** any entity resource method receives an empty or whitespace-only `company_id`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without making an HTTP request

### Requirement: Certificate value objects are immutable
The SDK SHALL provide `Nfe::CertificateInfo = Data.define(:subject, :issuer, :not_before, :not_after, :serial_number)` and `Nfe::CertificateStatus = Data.define(:has_certificate, :expires_on, :valid, :days_until_expiration, :expiring_soon, :details)`. Both SHALL be immutable `Data` value objects.

#### Scenario: CertificateInfo is frozen
- **WHEN** a `Nfe::CertificateInfo` instance is created
- **THEN** it SHALL be immutable (a `Data` instance), and attempting to mutate a field SHALL raise

### Requirement: Frozen string literals on every source file
Every Ruby source file added by this change SHALL begin with the magic comment `# frozen_string_literal: true`.

#### Scenario: Source file without the magic comment
- **WHEN** a contributor adds a file under `lib/nfe/resources/` without the `# frozen_string_literal: true` comment
- **THEN** RuboCop SHALL fail the build

