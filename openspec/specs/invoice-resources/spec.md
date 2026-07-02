# invoice-resources Specification

## Purpose
TBD - created by archiving change add-invoice-resources. Update Purpose after archive.
## Requirements
### Requirement: Five invoice resource classes are fully implemented
The SDK SHALL implement exactly five invoice resource classes under `Nfe::Resources` — `ServiceInvoices`, `ProductInvoices`, `ConsumerInvoices`, `TransportationInvoices`, and `InboundProductInvoices` — covering NFS-e, NF-e, NFC-e, inbound CT-e, and inbound supplier NF-e respectively. They SHALL be reachable through the lazy snake_case accessors `client.service_invoices`, `client.product_invoices`, `client.consumer_invoices`, `client.transportation_invoices`, and `client.inbound_product_invoices` defined by `add-client-core`.

Four of the five (service, product, transportation, inbound-product) match the Node.js SDK 1:1 in method names, parameter set, and return-shape category, modulo Ruby idioms: `Buffer` becomes a binary `String`, `Promise`/async becomes a synchronous return, and `camelCase` becomes `snake_case`. The fifth (`ConsumerInvoices`) is a **parity-plus** addition: the Node SDK does not expose NFC-e emission, but the NFE.io API supports it natively via `nf-consumidor-v2.yaml`.

The classic service-invoice emission lives in this capability. The new RTC (Reforma Tributária, IBS/CBS/IS) service-invoice and product-invoice emission models are out of scope here and are specified by the `add-rtc-invoice-emission` change.

#### Scenario: Accessing invoice resources from the client
- **WHEN** a consumer reads any of `client.service_invoices`, `client.product_invoices`, `client.consumer_invoices`, `client.transportation_invoices`, or `client.inbound_product_invoices`
- **THEN** the accessor SHALL return a fully functional resource instance (not a stub that raises `NotImplementedError`)
- **AND** repeated reads of the same accessor SHALL return the same memoized instance

#### Scenario: Parity with the Node SDK for the four shared resources
- **WHEN** comparing method names, parameter set, and return-shape category between this SDK and the Node SDK for `ServiceInvoices`, `ProductInvoices`, `TransportationInvoices`, or `InboundProductInvoices`
- **THEN** they SHALL be 1:1 equivalent, modulo Ruby idioms (binary `String` for downloads, synchronous returns, snake_case names)

#### Scenario: NFC-e emission beyond Node parity
- **WHEN** a consumer calls any method on `client.consumer_invoices`
- **THEN** the resource SHALL execute against `https://api.nfse.io/v2/companies/{company_id}/consumerinvoices/*` paths defined in `nf-consumidor-v2.yaml`, even though the equivalent method does not exist in the Node SDK

### Requirement: Invoice resources route to the host of their API family
Each invoice resource SHALL resolve its base URL through `Nfe::Configuration#base_url_for(family)` (provided by `add-client-core`) and SHALL NOT hard-code any host. `ServiceInvoices` SHALL use the `:main` family (`base_url_for(:main)` → host `https://api.nfe.io`, with the `/v1` segment supplied by the resource `api_version`, yielding effective URLs under `https://api.nfe.io/v1/...`). `ProductInvoices`, `ConsumerInvoices`, `TransportationInvoices`, and `InboundProductInvoices` SHALL use the `:cte` family (`https://api.nfse.io`).

#### Scenario: Service invoice routes to api.nfe.io
- **WHEN** any method of `ServiceInvoices` issues an HTTP request
- **THEN** the request host SHALL be `https://api.nfe.io` with the `/v1` base path segment

#### Scenario: Product, consumer, transportation, and inbound route to api.nfse.io
- **WHEN** any method of `ProductInvoices`, `ConsumerInvoices`, `TransportationInvoices`, or `InboundProductInvoices` issues an HTTP request
- **THEN** the request host SHALL be `https://api.nfse.io`, distinct from the `https://api.nfe.io` host used by `ServiceInvoices`

### Requirement: Service invoice creation supports the discriminated 202 contract
`ServiceInvoices#create(company_id:, data:)` SHALL accept a company ID and a request payload and SHALL return either a `Nfe::Resources::ServiceInvoicePending` (when the API responds HTTP 202 with a `Location` header) or a `Nfe::Resources::ServiceInvoiceIssued` (when the API responds HTTP 201 with the materialized invoice body).

#### Scenario: Async invoice creation
- **WHEN** the consumer calls `client.service_invoices.create(company_id:, data:)` and the API responds HTTP 202 with `Location: /v1/companies/{id}/serviceinvoices/{invoice_id}`
- **THEN** the method SHALL return a `ServiceInvoicePending` whose `invoice_id` matches the final path segment (extracted via `%r{serviceinvoices/([a-z0-9-]+)}i`) and whose `location` matches the header value
- **AND** `pending?` SHALL be `true` and `issued?` SHALL be `false`

#### Scenario: Immediate invoice creation
- **WHEN** the API responds HTTP 201 with the invoice body
- **THEN** the method SHALL return a `ServiceInvoiceIssued` whose `resource` is the typed invoice model hydrated from the response body
- **AND** `issued?` SHALL be `true` and `pending?` SHALL be `false`

#### Scenario: Async response missing the Location header
- **WHEN** the API responds HTTP 202 but no `Location` header is present, or the invoice ID cannot be extracted from it
- **THEN** the SDK SHALL raise `Nfe::InvoiceProcessingError`

### Requirement: Emission methods accept an idempotency key and per-call request options
The emission methods — `create` and `create_with_state_tax` on `ServiceInvoices`, `ProductInvoices`, and `ConsumerInvoices` — SHALL accept two optional keyword arguments: `idempotency_key:` (default `nil`) and `request_options:` (default `nil`).

When `idempotency_key:` is supplied, the SDK SHALL send it as the HTTP `Idempotency-Key` request header. The caller supplies a stable key tied to a business identifier. The SDK SHALL NOT auto-retry the POST; the documented safe-retry pattern is for the caller to re-invoke the same emission method with the SAME `idempotency_key:` after a timeout, so the server deduplicates and no duplicate fiscal document is issued.

When `request_options:` is supplied, it SHALL be a `Nfe::RequestOptions` value object (provided by `add-client-core`) and `Nfe::Resources::AbstractResource` SHALL thread its `api_key`/`base_url`/`timeout` overrides into the request for that single call, without requiring a second `Client`. This capability SHALL NOT redefine `Nfe::RequestOptions`; it consumes it.

#### Scenario: Idempotency key sent as a header
- **WHEN** `create(company_id:, data:, idempotency_key: 'order-42')` is called
- **THEN** the issued HTTP POST SHALL carry the header `Idempotency-Key: order-42`

#### Scenario: Safe retry reuses the same key
- **WHEN** an emission call times out and the caller re-invokes the same method with the SAME `idempotency_key:`
- **THEN** the SDK SHALL send the identical `Idempotency-Key` header and SHALL NOT auto-retry the POST on its own, so the server can deduplicate and avoid issuing a duplicate fiscal document

#### Scenario: Per-call request options override the client defaults
- **WHEN** `create(company_id:, data:, request_options: Nfe::RequestOptions.new(api_key: 'tenant-key', base_url: nil, timeout: nil))` is called
- **THEN** that single request SHALL authenticate with `tenant-key` instead of the `Client`'s default api_key, leaving the shared `Client` unchanged

#### Scenario: Emission without the optional kwargs is unchanged
- **WHEN** `create(company_id:, data:)` is called without `idempotency_key:` or `request_options:`
- **THEN** the SDK SHALL issue the request with no `Idempotency-Key` header and using the `Client`'s default configuration

### Requirement: Service invoice CRUD, email, downloads, and status
`ServiceInvoices` SHALL expose `create`, `list`, `retrieve`, `cancel`, `send_email`, `download_pdf`, `download_xml`, and `get_status`. Every method that takes a company ID or invoice ID SHALL validate it through `Nfe::IdValidator` (provided by `add-client-core`) before issuing the HTTP request.

| Method | HTTP | Path |
|---|---|---|
| `create(company_id:, data:, idempotency_key: nil, request_options: nil)` | POST | `/companies/{company_id}/serviceinvoices` |
| `list(company_id:, **options)` | GET | `/companies/{company_id}/serviceinvoices` |
| `retrieve(company_id:, invoice_id:)` | GET | `/companies/{company_id}/serviceinvoices/{invoice_id}` |
| `cancel(company_id:, invoice_id:)` | DELETE | `/companies/{company_id}/serviceinvoices/{invoice_id}` |
| `send_email(company_id:, invoice_id:)` | PUT | `/companies/{company_id}/serviceinvoices/{invoice_id}/sendemail` |
| `download_pdf(company_id:, invoice_id: nil)` | GET | `.../{invoice_id}/pdf` or `.../serviceinvoices/pdf` (bulk) |
| `download_xml(company_id:, invoice_id: nil)` | GET | `.../{invoice_id}/xml` or `.../serviceinvoices/xml` (bulk) |
| `get_status(company_id:, invoice_id:)` | (derived) | derived from `retrieve` — no extra HTTP call |

#### Scenario: Page-style listing
- **WHEN** `list(company_id:, page_index: 0, page_count: 20, issued_begin: '2026-01-01', issued_end: '2026-01-31')` is called
- **THEN** the SDK SHALL return a `Nfe::ListResponse` whose `page` carries `page_index`/`page_count` (cursor fields `nil`) and whose `data` is the unwrapped `serviceInvoices` array

#### Scenario: Retrieve returns a typed model
- **WHEN** `retrieve(company_id:, invoice_id:)` succeeds
- **THEN** the return value SHALL be a typed invoice model (a generated model, or a hand-written `Nfe::ServiceInvoice` value object where the generated tree does not cover the shape) hydrated from the response body

#### Scenario: Retrieve not found
- **WHEN** `retrieve(company_id:, invoice_id:)` receives HTTP 404, or the response body is empty
- **THEN** the SDK SHALL raise `Nfe::NotFoundError`

#### Scenario: Cancel is synchronous
- **WHEN** `cancel(company_id:, invoice_id:)` succeeds
- **THEN** the SDK SHALL return the updated invoice model from the response body

#### Scenario: Send email
- **WHEN** `send_email(company_id:, invoice_id:)` succeeds
- **THEN** the SDK SHALL issue a `PUT` to `.../sendemail` and return the send result carrying a `sent` flag

#### Scenario: Bulk download with no invoice ID
- **WHEN** `download_pdf(company_id:)` is called with `invoice_id` omitted
- **THEN** the SDK SHALL request `.../serviceinvoices/pdf` and return the ZIP bytes as a binary `String`

#### Scenario: Status derived without an HTTP call
- **WHEN** `get_status(company_id:, invoice_id:)` is called
- **THEN** the SDK SHALL call `retrieve` exactly once and SHALL return a value carrying `status`, `invoice`, `complete?` (via `FlowStatus.terminal?`), and `failed?` (true for `IssueFailed`/`CancelFailed`), making no separate status HTTP request

### Requirement: Product invoice resource mirrors Node SDK breadth
`ProductInvoices` SHALL expose `create`, `create_with_state_tax`, `list`, `retrieve`, `cancel`, `list_items`, `list_events`, `download_pdf`, `download_xml`, `download_rejection_xml`, `download_epec_xml`, `send_correction_letter`, `download_correction_letter_pdf`, `download_correction_letter_xml`, `disable`, and `disable_range`, all under `/v2/companies/{company_id}/productinvoices*` on `https://api.nfse.io`.

Pagination on `list`, `list_items`, and `list_events` uses cursor semantics (`starting_after`, `ending_before`, `limit`). The `environment` query parameter on `list` is required.

Both `create` and `create_with_state_tax` SHALL accept the optional `idempotency_key:` and `request_options:` keyword arguments described in the dedicated emission-options requirement.

#### Scenario: Discriminated creation
- **WHEN** `create(company_id:, data:)` is called and the API enqueues the invoice (HTTP 202)
- **THEN** the method SHALL return a `Nfe::Resources::ProductInvoicePending`; on HTTP 201 it SHALL return a `Nfe::Resources::ProductInvoiceIssued`

#### Scenario: Creation scoped to a state tax registration
- **WHEN** `create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)` is called
- **THEN** the SDK SHALL route to `/v2/companies/{company_id}/statetaxes/{state_tax_id}/productinvoices` and SHALL validate `state_tax_id` via `IdValidator` before the request, forwarding `idempotency_key:` as the `Idempotency-Key` header when present

#### Scenario: Cursor-style listing requires environment
- **WHEN** `list(company_id:, environment: 'Production', limit: 50)` is called
- **THEN** the SDK SHALL return a `ListResponse` whose `page` carries `starting_after`/`ending_before` cursors (not `page_index`)

#### Scenario: Listing without environment is rejected
- **WHEN** `list(company_id:)` is called without an `environment`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without an HTTP request

#### Scenario: Cancel forwards a reason
- **WHEN** `cancel(company_id:, invoice_id:, reason: 'Erro de digitação')` is called
- **THEN** the SDK SHALL issue `DELETE .../{invoice_id}?reason=...` and return the cancellation resource (the cancellation is asynchronous)

#### Scenario: Product invoice downloads return a file URI, not bytes
- **WHEN** `download_pdf`, `download_xml`, `download_rejection_xml`, or `download_epec_xml` succeeds
- **THEN** the return value SHALL be a `Nfe::NfeFileResource` carrying a URI to the file — NOT raw bytes — distinguishing this resource from the byte-returning downloads on the other invoice resources

#### Scenario: Correction letter length validation
- **WHEN** `send_correction_letter(company_id:, invoice_id:, reason:)` is called with a `reason` whose length is outside `15..1000`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without an HTTP request; with a valid length it SHALL `PUT .../correctionletter` with body `{ reason: }`

#### Scenario: Per-invoice and range disablement
- **WHEN** `disable(company_id:, invoice_id:, reason:)` is called
- **THEN** the SDK SHALL `POST .../{invoice_id}/disablement?reason=...`
- **WHEN** `disable_range(company_id:, data:)` is called with `{ environment, serie, state, begin_number, last_number, reason? }`
- **THEN** the SDK SHALL `POST /v2/companies/{company_id}/productinvoices/disablement`

### Requirement: Consumer invoice resource exposes the NFC-e emission lifecycle
`ConsumerInvoices` SHALL target `https://api.nfse.io` under v2 (`base_url_for(:cte)`) and SHALL expose the following methods backed by `nf-consumidor-v2.yaml`:

| Method | HTTP | Path |
|---|---|---|
| `create(company_id:, data:, idempotency_key: nil, request_options: nil)` | POST | `/v2/companies/{company_id}/consumerinvoices` |
| `create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)` | POST | `.../statetaxes/{state_tax_id}/consumerinvoices` |
| `list(company_id:, **options)` | GET | `/v2/companies/{company_id}/consumerinvoices` |
| `retrieve(company_id:, invoice_id:)` | GET | `.../consumerinvoices/{invoice_id}` |
| `cancel(company_id:, invoice_id:)` | DELETE | `.../consumerinvoices/{invoice_id}` |
| `list_items(company_id:, invoice_id:)` | GET | `.../{invoice_id}/items` |
| `list_events(company_id:, invoice_id:)` | GET | `.../{invoice_id}/events` |
| `download_pdf(company_id:, invoice_id:)` | GET | `.../{invoice_id}/pdf` |
| `download_xml(company_id:, invoice_id:)` | GET | `.../{invoice_id}/xml` |
| `download_rejection_xml(company_id:, invoice_id:)` | GET | `.../{invoice_id}/xml/rejection` |
| `disable_range(company_id:, data:)` | POST | `.../consumerinvoices/disablement` |

The resource SHALL NOT define `send_correction_letter` (CC-e applies only to NF-e by Brazilian fiscal law), `download_epec_xml` (no EPEC contingency exists for NFC-e), nor a per-invoice `disable` (NFC-e supports only collective inutilization via `disable_range`).

#### Scenario: NFC-e discriminated creation
- **WHEN** `create(company_id:, data:)` is called and the API responds HTTP 202 with `Location`
- **THEN** the method SHALL return a `Nfe::Resources::ConsumerInvoicePending` whose `invoice_id` is extracted from the final path segment; on HTTP 201 it SHALL return a `Nfe::Resources::ConsumerInvoiceIssued` whose `resource` is a `Nfe::ConsumerInvoice`

#### Scenario: NFC-e cancellation is synchronous
- **WHEN** `cancel(company_id:, invoice_id:)` is called
- **THEN** the SDK SHALL `DELETE .../consumerinvoices/{invoice_id}` and return the updated consumer-invoice model

#### Scenario: NFC-e download returns bytes
- **WHEN** `download_pdf(company_id:, invoice_id:)` succeeds
- **THEN** the return value SHALL be a binary `String` (the DANFE NFC-e PDF), unlike `ProductInvoices` which returns a URI

#### Scenario: NFC-e collective inutilization only
- **WHEN** `disable_range(company_id:, data:)` is called
- **THEN** the SDK SHALL `POST .../consumerinvoices/disablement`

#### Scenario: Methods absent by fiscal law
- **WHEN** consumer code calls `client.consumer_invoices.send_correction_letter(...)`, `download_epec_xml(...)`, or `disable(...)`
- **THEN** Ruby SHALL raise `NoMethodError`, because those instruments do not exist for NFC-e

### Requirement: Transportation invoice resource (CT-e inbound)
`TransportationInvoices` SHALL manage inbound CT-e via the `:cte` family (`https://api.nfse.io`) and SHALL expose `enable`, `disable`, `get_settings`, `retrieve` (by access key), `download_xml`, `get_event`, and `download_event_xml`.

| Method | HTTP | Path |
|---|---|---|
| `enable(company_id:, start_from_nsu: nil, start_from_date: nil)` | POST | `/v2/companies/{company_id}/inbound/transportationinvoices` |
| `disable(company_id:)` | DELETE | `.../inbound/transportationinvoices` |
| `get_settings(company_id:)` | GET | `.../inbound/transportationinvoices` |
| `retrieve(company_id:, access_key:)` | GET | `.../inbound/{access_key}` |
| `download_xml(company_id:, access_key:)` | GET | `.../inbound/{access_key}/xml` |
| `get_event(company_id:, access_key:, event_key:)` | GET | `.../inbound/{access_key}/events/{event_key}` |
| `download_event_xml(company_id:, access_key:, event_key:)` | GET | `.../inbound/{access_key}/events/{event_key}/xml` |

#### Scenario: Enabling auto-fetch returns settings
- **WHEN** `enable(company_id:)` is called
- **THEN** the SDK SHALL `POST .../inbound/transportationinvoices` and return the inbound settings model

#### Scenario: Access key normalisation
- **WHEN** `retrieve(company_id:, access_key:)` is called with a 44-digit key containing spaces or dots
- **THEN** `Nfe::IdValidator.access_key` SHALL strip non-digits and the request SHALL use the 44-digit value
- **AND** if the normalised value does not match `/\A\d{44}\z/` the SDK SHALL raise `Nfe::InvalidRequestError` before any HTTP request

#### Scenario: XML downloads return strings
- **WHEN** `download_xml(company_id:, access_key:)` or `download_event_xml(company_id:, access_key:, event_key:)` succeeds
- **THEN** the return value SHALL be a `String` containing the raw XML

### Requirement: Inbound product invoice resource manages supplier NF-e ingestion
`InboundProductInvoices` SHALL manage supplier-issued NF-e via the `:cte` family (`https://api.nfse.io`) and SHALL expose `enable_auto_fetch`, `disable_auto_fetch`, `get_settings`, `get_details`, `get_product_invoice_details`, `get_event_details`, `get_product_invoice_event_details`, `get_xml`, `get_event_xml`, `get_pdf`, `get_json`, `manifest`, and `reprocess_webhook`.

The `manifest` method SHALL accept a numeric `tp_event` (default `210210`) and forward it as a query parameter. The module SHALL expose symbolic constants for the manifest event types: `210210` awareness (default), `210220` confirmation, `210240` operation not performed.

| Method | HTTP | Path |
|---|---|---|
| `enable_auto_fetch(company_id:, **opts)` | POST | `/v2/companies/{company_id}/inbound/productinvoices` |
| `disable_auto_fetch(company_id:)` | DELETE | `.../inbound/productinvoices` |
| `get_settings(company_id:)` | GET | `.../inbound/productinvoices` |
| `get_details(company_id:, access_key:)` | GET | `.../inbound/{access_key}` |
| `get_product_invoice_details(company_id:, access_key:)` | GET | `.../inbound/productinvoice/{access_key}` |
| `get_event_details(company_id:, access_key:, event_key:)` | GET | `.../inbound/{access_key}/events/{event_key}` |
| `get_product_invoice_event_details(company_id:, access_key:, event_key:)` | GET | `.../inbound/productinvoice/{access_key}/events/{event_key}` |
| `get_xml(company_id:, access_key:)` | GET | `.../inbound/{access_key}/xml` |
| `get_event_xml(company_id:, access_key:, event_key:)` | GET | `.../inbound/{access_key}/events/{event_key}/xml` |
| `get_pdf(company_id:, access_key:)` | GET | `.../inbound/{access_key}/pdf` |
| `get_json(company_id:, access_key:)` | GET | `.../inbound/productinvoice/{access_key}/json` |
| `manifest(company_id:, access_key:, tp_event: 210210)` | POST | `.../inbound/{access_key}/manifest?tpEvent={tp_event}` |
| `reprocess_webhook(company_id:, access_key_or_nsu:)` | POST | `.../inbound/productinvoice/{access_key_or_nsu}/processwebhook` |

#### Scenario: v1 versus v2 detail endpoints
- **WHEN** `get_details(company_id:, access_key:)` is called
- **THEN** the SDK SHALL request `.../inbound/{access_key}` (webhook v1 format)
- **WHEN** `get_product_invoice_details(company_id:, access_key:)` is called
- **THEN** the SDK SHALL request `.../inbound/productinvoice/{access_key}` (webhook v2 format)

#### Scenario: Manifesting receipt with default event type
- **WHEN** `manifest(company_id:, access_key:)` is called without `tp_event`
- **THEN** the SDK SHALL `POST .../manifest?tpEvent=210210` (awareness) and return the result as a `String`

#### Scenario: Manifesting receipt with explicit event type
- **WHEN** `manifest(company_id:, access_key:, tp_event: 210220)` is called
- **THEN** the SDK SHALL `POST .../manifest?tpEvent=210220` (confirmation)

#### Scenario: PDF download returns bytes
- **WHEN** `get_pdf(company_id:, access_key:)` succeeds
- **THEN** the return value SHALL be a binary `String` (the PDF bytes)

#### Scenario: Reprocess accepts key or NSU
- **WHEN** `reprocess_webhook(company_id:, access_key_or_nsu:)` is called with either a 44-digit access key or a numeric NSU
- **THEN** the SDK SHALL `POST .../inbound/productinvoice/{access_key_or_nsu}/processwebhook` and SHALL NOT reject a numeric NSU as an invalid access key

### Requirement: Discriminated response value objects for invoice creation
The SDK SHALL provide the following immutable `Data.define` value objects under `Nfe::Resources`, each exposing `pending?` and `issued?` predicate methods:

- `ServiceInvoicePending(:invoice_id, :location)` and `ServiceInvoiceIssued(:resource)`
- `ProductInvoicePending(:invoice_id, :location)` and `ProductInvoiceIssued(:resource)`
- `ConsumerInvoicePending(:invoice_id, :location)` and `ConsumerInvoiceIssued(:resource)`

These implement the `Pending`/`Issued` contract introduced by `add-client-core`.

#### Scenario: Discriminating with a predicate
- **WHEN** a consumer writes `result.pending? ? handle_pending(result) : handle_issued(result)`
- **THEN** a `*Pending` value SHALL answer `pending?` with `true` and expose `invoice_id`/`location`, and a `*Issued` value SHALL answer `issued?` with `true` and expose `resource`

#### Scenario: Discriminating with pattern matching
- **WHEN** a consumer writes `case result; in Nfe::Resources::ServiceInvoicePending; ...; in Nfe::Resources::ServiceInvoiceIssued; ...; end`
- **THEN** Ruby `Data` pattern matching SHALL select the correct branch for the returned value object

### Requirement: Invoice resources validate IDs and access keys before HTTP
Every invoice resource method that takes an identifier SHALL validate it through the `Nfe::IdValidator` module provided by `add-client-core` — calling `company_id`, `invoice_id`, `state_tax_id`, `event_key`, or `access_key` — before issuing the HTTP request. This capability SHALL NOT redefine the validator; it consumes the one defined by `add-client-core`.

`Nfe::IdValidator.access_key` accepts formatted input (with spaces, dots, dashes), strips non-digit characters, validates that the result has exactly 44 digits (`/\A\d{44}\z/`), and returns the normalised string.

#### Scenario: Empty company ID rejected before HTTP
- **WHEN** any resource method receives an empty or whitespace-only company ID
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously, with a Portuguese-language message naming the invalid argument, and SHALL make no HTTP request

#### Scenario: Access key with formatting is normalised
- **WHEN** a resource method receives a 44-digit access key with separators and calls `Nfe::IdValidator.access_key`
- **THEN** the validator SHALL return a 44-character digit-only `String` and SHALL NOT raise

#### Scenario: Access key of wrong length rejected
- **WHEN** a resource method receives an access key that normalises to fewer than 44 digits
- **THEN** `Nfe::IdValidator.access_key` SHALL raise `Nfe::InvalidRequestError` before any HTTP request

### Requirement: Invoice listings use the shared ListResponse pagination type
Every invoice resource `list`/`list_items`/`list_events` method SHALL return the `Nfe::ListResponse` value object provided by `add-client-core` (carrying `data` and a `Nfe::ListPage`), populating only the half of `ListPage` (`page_index`/`page_count` for page-style, or `starting_after`/`ending_before` for cursor-style) relevant to its endpoint. This capability SHALL NOT redefine `ListResponse`/`ListPage`; it consumes them.

#### Scenario: Page-style listing
- **WHEN** a resource paginates with `page_index`/`page_count` (e.g., service invoices)
- **THEN** the returned `ListResponse.page` SHALL have `page_index` and `page_count` set and cursor fields `nil`

#### Scenario: Cursor-style listing
- **WHEN** a resource paginates with `starting_after`/`ending_before` (e.g., product or consumer invoices)
- **THEN** the returned `ListResponse.page` SHALL have the cursor fields set and `page_index` `nil`

#### Scenario: Iterating a list response
- **WHEN** a consumer calls `result.each { |item| ... }` or `result.map { ... }` on a `ListResponse`
- **THEN** the iteration SHALL traverse the underlying `data` array via the `Enumerable` included by `add-client-core`

### Requirement: Invoice status checks use the shared FlowStatus helper
Manual polling and `ServiceInvoices#get_status` SHALL determine terminal state through `Nfe::FlowStatus.terminal?(status)` provided by `add-client-core`, which returns `true` for `Issued`, `Cancelled`, `IssueFailed`, and `CancelFailed`, and `false` otherwise. This capability SHALL NOT redefine `FlowStatus`; it consumes it.

#### Scenario: Terminal status
- **WHEN** `Nfe::FlowStatus.terminal?('Issued')`, `'Cancelled'`, `'IssueFailed'`, or `'CancelFailed'` is called
- **THEN** the method SHALL return `true`

#### Scenario: Non-terminal status
- **WHEN** `Nfe::FlowStatus.terminal?('WaitingDefineRpsNumber')` or any other non-terminal value is called
- **THEN** the method SHALL return `false`

### Requirement: Byte downloads return binary-safe strings
The byte-returning download methods — `ServiceInvoices#download_pdf`/`download_xml`, `ConsumerInvoices#download_pdf`/`download_xml`/`download_rejection_xml`, `TransportationInvoices#download_xml`/`download_event_xml`, and `InboundProductInvoices#get_xml`/`get_event_xml`/`get_pdf` — SHALL return a Ruby `String` containing the raw response bytes with encoding forced to `Encoding::ASCII_8BIT`. They SHALL set the appropriate `Accept` header (`application/pdf` or `application/xml`) and SHALL NOT attempt to parse the body as JSON.

This requirement does NOT apply to `ProductInvoices` download methods, which return a `Nfe::NfeFileResource` (URI) instead of bytes.

#### Scenario: PDF download bytes
- **WHEN** any covered `download_pdf`/`get_pdf` method succeeds
- **THEN** the return value SHALL be an `ASCII-8BIT` `String` whose first four bytes are `%PDF`

#### Scenario: XML download bytes
- **WHEN** any covered `download_xml`/`get_xml` method succeeds
- **THEN** the return value SHALL be an `ASCII-8BIT` `String` whose first non-BOM character is `<`

### Requirement: create_and_wait and create_batch are deferred
The SDK v1.0 SHALL NOT implement `create_and_wait` or `create_batch` on any invoice resource. The discriminated `Pending`/`Issued` contract plus `FlowStatus.terminal?` are sufficient for manual polling loops in CLI/worker contexts. Both helpers are explicitly deferred to a future minor release.

#### Scenario: Looking for create_and_wait
- **WHEN** consumer code calls `client.service_invoices.create_and_wait(...)` against v1.0
- **THEN** Ruby SHALL raise `NoMethodError`, since the method is not defined

### Requirement: RTC emission is delegated to a separate change
This capability SHALL implement only the classic service-invoice and product-invoice emission. The RTC (Reforma Tributária do Consumo) emission models — adding the IBS, CBS, and IS tax groups — SHALL NOT be implemented here; they are specified by the `add-rtc-invoice-emission` change, which reuses the 202 contract, host routing, and validators defined in this capability.

#### Scenario: Classic emission only
- **WHEN** a consumer issues a service or product invoice through this capability's `create` methods
- **THEN** the SDK SHALL send the classic (non-RTC) payload shape, and any IBS/CBS/IS handling SHALL be provided by the dedicated RTC resources from `add-rtc-invoice-emission`

