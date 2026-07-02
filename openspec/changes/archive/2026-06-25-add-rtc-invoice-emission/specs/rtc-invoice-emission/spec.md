# rtc-invoice-emission — Delta

## ADDED Requirements

### Requirement: Dedicated RTC service-invoice resource exposed on the Client

The SDK SHALL expose a dedicated resource `client.service_invoices_rtc` for emitting service invoices (NFS-e) under the Reforma Tributária do Consumo (RTC) layout. The classic `client.service_invoices` resource (from `add-invoice-resources`) SHALL remain unchanged; RTC emission SHALL be opt-in via the new resource.

The resource SHALL target the `main` API family — host `https://api.nfe.io` (`base_url_for(:main)`), with the `/v1` segment supplied by the resource `api_version`, yielding effective URLs under `https://api.nfe.io/v1/...` — resolved through `Nfe::Configuration`, reusing the same host client as the classic `service_invoices` resource. No new base URL SHALL be introduced.

#### Scenario: Accessing the RTC resource from the Client

- **WHEN** a consumer reads `client.service_invoices_rtc`
- **THEN** the accessor SHALL return a fully functional `Nfe::Resources::ServiceInvoicesRtc` instance (lazily created and memoized), not a stub that raises `NoMethodError`

#### Scenario: RTC reuses the main host without a new base URL

- **WHEN** any method of `service_invoices_rtc` issues an HTTP request
- **THEN** the outgoing request SHALL target the host `https://api.nfe.io` (the `main` family, with the `/v1` segment supplied by the resource `api_version`, effective URL `https://api.nfe.io/v1/...`), the same host used by the classic `service_invoices` resource
- **AND** no new base-URL constant SHALL be added to `Nfe::Configuration`

#### Scenario: Classic service-invoice resource is unaffected

- **WHEN** the RTC resource is added to the Client
- **THEN** `client.service_invoices` SHALL keep its existing method signatures and behavior unchanged

### Requirement: RTC service-invoice emission supports the discriminated 202 contract

`Nfe::Resources::ServiceInvoicesRtc#create` SHALL accept keyword arguments `company_id:` and `data:`, where `data` is an `Nfe::Generated::ServiceInvoiceRtcV1::NFSeRequest` value object or a `Hash`. It SHALL issue `POST /companies/{company_id}/serviceinvoices` and SHALL return either a `Nfe::Resources::ServiceInvoiceRtcPending` (when the API responds HTTP 202 with a `Location` header) or a `Nfe::Resources::ServiceInvoiceRtcIssued` (when the API responds HTTP 201 with the materialized invoice body).

The RTC layout SHALL be selected by the presence of the `ibsCbs` group in the payload — there is no header or query parameter. This is the same endpoint the classic `service_invoices` resource uses.

`#create` SHALL additionally accept an optional `idempotency_key:` keyword (sent as the `Idempotency-Key` HTTP header for safe retries) and an optional `request_options:` keyword (an `Nfe::RequestOptions` from `add-client-core`, threaded into the request to override `api_key`/`base_url`/`timeout` per call). POST SHALL NOT be auto-retried by the transport.

#### Scenario: Idempotency key forwarded as a header

- **WHEN** `create(company_id:, data:, idempotency_key: "service-rtc-42")` is called
- **THEN** the outgoing request SHALL carry the `Idempotency-Key: service-rtc-42` header
- **AND** when `idempotency_key:` is omitted, no `Idempotency-Key` header SHALL be sent

#### Scenario: Per-call request options override the Client defaults

- **WHEN** `create(company_id:, data:, request_options: Nfe::RequestOptions.new(api_key: "tenant-key", base_url: nil, timeout: nil))` is called
- **THEN** the request SHALL authenticate with `tenant-key` for that call only, without mutating the shared Client

#### Scenario: Async emission returns a Pending result

- **WHEN** `client.service_invoices_rtc.create(company_id:, data:)` is called and the API responds HTTP 202 with `Location: /v1/companies/{company_id}/serviceinvoices/{invoice_id}`
- **THEN** the method SHALL return a `Nfe::Resources::ServiceInvoiceRtcPending` whose `invoice_id` matches the final path segment of the `Location` header (extracted via `%r{serviceinvoices/([a-z0-9-]+)}i`)
- **AND** whose `location` matches the header value

#### Scenario: Immediate emission returns an Issued result

- **WHEN** the API responds HTTP 201 with the invoice body
- **THEN** the method SHALL return a `Nfe::Resources::ServiceInvoiceRtcIssued` whose `resource` returns a service-invoice RTC DTO hydrated from the response body

#### Scenario: 202 without a Location header raises a processing error

- **WHEN** the API responds HTTP 202 but omits the `Location` header
- **THEN** the SDK SHALL raise `Nfe::InvoiceProcessingError`

#### Scenario: Payload carries the ibsCbs group

- **WHEN** `create` is called with the spec's minimum payload (`borrower`, `cityServiceCode`, `federalServiceCode`, `description`, `servicesAmount`, `nbsCode`, and an `ibsCbs` group)
- **THEN** the serialized request body SHALL contain the `ibsCbs` group with `operationIndicator` matching `^[0-9]{6}$` and a `classCode` of at most 6 characters
- **AND** both `operationIndicator` and `classCode` SHALL be required within the `ibsCbs` group

### Requirement: RTC service-invoice retrieve and cancel

`Nfe::Resources::ServiceInvoicesRtc` SHALL expose `retrieve(company_id:, invoice_id:)` issuing `GET /companies/{company_id}/serviceinvoices/{invoice_id}` and `cancel(company_id:, invoice_id:)` issuing `DELETE /companies/{company_id}/serviceinvoices/{invoice_id}`.

#### Scenario: Retrieve returns a typed DTO

- **WHEN** `retrieve(company_id:, invoice_id:)` succeeds
- **THEN** the return value SHALL be a service-invoice RTC value object (`Data.define`) hydrated from the response body, exposing at least `flow_status`

#### Scenario: Retrieve of a missing invoice raises NotFoundError

- **WHEN** `retrieve(company_id:, invoice_id:)` receives HTTP 404
- **THEN** the SDK SHALL raise `Nfe::NotFoundError`

#### Scenario: Cancel returns the updated invoice synchronously

- **WHEN** `cancel(company_id:, invoice_id:)` is called
- **THEN** the SDK SHALL issue the `DELETE` request and return the updated service-invoice RTC DTO

### Requirement: Download the cancellation-event XML (Ambiente Nacional)

`Nfe::Resources::ServiceInvoicesRtc` SHALL expose `download_cancellation_xml(company_id:, invoice_id:)` issuing `GET /companies/{company_id}/serviceinvoices/{invoice_id}/cancellation-xml` with `Accept: application/xml`. It SHALL return the cancellation-event (`e110001`) XML as a binary-safe `String` (encoding `ASCII-8BIT`). This endpoint is available only for invoices in the Ambiente Nacional (ADN) and only after the invoice reaches the `Cancelled` status.

#### Scenario: Cancellation XML returns raw bytes

- **WHEN** `download_cancellation_xml(company_id:, invoice_id:)` succeeds for a cancelled Ambiente Nacional invoice
- **THEN** the return value SHALL be a `String` whose encoding is `ASCII-8BIT` and whose first non-BOM character is `<`

#### Scenario: Municipal/ABRASF provider has no cancellation event

- **WHEN** `download_cancellation_xml` is called for an invoice from a municipal/ABRASF provider, or for an invoice not yet cancelled, and the API responds HTTP 404
- **THEN** the SDK SHALL raise `Nfe::NotFoundError`

### Requirement: Fail-fast identifier validation before the HTTP request

Every `ServiceInvoicesRtc` method that takes a `company_id` or `invoice_id` SHALL validate it through `Nfe::IdValidator` (from `add-client-core`) before issuing any HTTP request, raising `Nfe::InvalidRequestError` synchronously on empty or whitespace-only values.

#### Scenario: Empty company ID rejected before HTTP

- **WHEN** any `ServiceInvoicesRtc` method is called with an empty or whitespace-only `company_id`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` with a Portuguese-language message identifying the invalid argument
- **AND** no HTTP request SHALL be issued

#### Scenario: Empty invoice ID rejected before HTTP

- **WHEN** `retrieve`, `cancel`, or `download_cancellation_xml` is called with an empty `invoice_id`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` without issuing an HTTP request

### Requirement: Discriminated RTC response classes

The SDK SHALL provide concrete, immutable response classes for RTC service-invoice creation, implementing the `Pending` and `Issued` protocols defined in `add-client-core`:

- `Nfe::Resources::ServiceInvoiceRtcPending` implementing `Pending` — exposing `invoice_id`, `location`, and the predicate `pending?` (returning `true`) / `issued?` (returning `false`)
- `Nfe::Resources::ServiceInvoiceRtcIssued` implementing `Issued` — exposing `resource` typed at the service-invoice RTC DTO, and the predicate `issued?` (returning `true`) / `pending?` (returning `false`)

#### Scenario: Discriminating with is_a?

- **WHEN** a consumer writes `if result.is_a?(Nfe::Resources::ServiceInvoiceRtcPending) then ... else ... end`
- **THEN** the pending branch SHALL expose `invoice_id`/`location` and the issued branch SHALL expose `resource`
- **AND** the two classes SHALL be distinct from the classic `Nfe::Resources::ServiceInvoicePending`/`Nfe::Resources::ServiceInvoiceIssued`

#### Scenario: Discriminating with predicate methods

- **WHEN** a consumer receives the result of `create` and calls `result.pending?` / `result.issued?`
- **THEN** `Nfe::Resources::ServiceInvoiceRtcPending#pending?` SHALL return `true` and `#issued?` SHALL return `false`
- **AND** `Nfe::Resources::ServiceInvoiceRtcIssued#issued?` SHALL return `true` and `#pending?` SHALL return `false`

### Requirement: RTC DTOs are generated from the named OpenAPI schemas

The OpenAPI pipeline (from `add-openapi-pipeline`) SHALL sync `service-invoice-rtc-v1.yaml` from `nfeio-docs` and emit immutable `Data.define` value objects under `lib/nfe/generated/service_invoice_rtc_v1/` for the spec's named schemas, including `NFSeRequest` and the nested `ibsCbs` group, plus corresponding `.rbs` signatures under `sig/`. Generated files SHALL NOT be hand-edited.

#### Scenario: NFSeRequest generated as an immutable value object

- **WHEN** the pipeline generates types from `service-invoice-rtc-v1.yaml`
- **THEN** `Nfe::Generated::ServiceInvoiceRtcV1::NFSeRequest` SHALL exist as a `Data.define` value object exposing snake_case accessors (e.g., `services_amount`, `nbs_code`, `city_service_code`)
- **AND** it SHALL carry the nested `ibsCbs` group with `operation_indicator`, `class_code`, `situation_code`, `ibs`, and `cbs`

#### Scenario: Generated files carry the frozen-string-literal magic comment

- **WHEN** any file under `lib/nfe/generated/service_invoice_rtc_v1/` is generated
- **THEN** it SHALL start with `# frozen_string_literal: true`

### Requirement: Manual polling via FlowStatus terminal-state helper

The SDK SHALL support manual polling of RTC emission by reusing `Nfe::FlowStatus.terminal?` from `add-client-core`. The SDK v1 SHALL NOT implement `create_and_wait` or `create_batch` on the RTC resource.

#### Scenario: Polling until a terminal flow status

- **WHEN** a consumer receives a `Nfe::Resources::ServiceInvoiceRtcPending` and loops calling `retrieve` until `Nfe::FlowStatus.terminal?(invoice.flow_status)` returns `true`
- **THEN** the loop SHALL terminate when `flow_status` is one of `Issued`, `IssueFailed`, `Cancelled`, or `CancelFailed`

#### Scenario: create_and_wait is not defined

- **WHEN** consumer code calls `client.service_invoices_rtc.create_and_wait(...)`
- **THEN** Ruby SHALL raise `NoMethodError`, since the method is not defined in v1

### Requirement: Dedicated RTC product-invoice resource exposed on the Client

The SDK SHALL expose a dedicated resource `client.product_invoices_rtc` for emitting product invoices (NF-e modelo 55 and NFC-e modelo 65) under the Reforma Tributária do Consumo (RTC) layout. The classic `client.product_invoices` resource (from `add-invoice-resources`) SHALL remain unchanged; RTC emission SHALL be opt-in via the new resource.

The resource SHALL target the `cte` API family (alias `:product_invoices`) — host `https://api.nfse.io` (`base_url_for(:cte)`), with the `/v2` segment supplied by the resource `api_version`, yielding effective URLs under `https://api.nfse.io/v2/...` — resolved through `Nfe::Configuration`, reusing the same host client as the classic `product_invoices` resource. No new base URL SHALL be introduced, and the resource SHALL NOT be routed to the `main` host `https://api.nfe.io`.

#### Scenario: Accessing the product RTC resource from the Client

- **WHEN** a consumer reads `client.product_invoices_rtc`
- **THEN** the accessor SHALL return a fully functional `Nfe::Resources::ProductInvoicesRtc` instance (lazily created and memoized), not a stub that raises `NoMethodError`

#### Scenario: Product RTC reuses the api.nfse.io host without a new base URL

- **WHEN** any method of `product_invoices_rtc` issues an HTTP request
- **THEN** the outgoing request SHALL target the host `https://api.nfse.io` (the `cte` family, with the `/v2` segment supplied by the resource `api_version`, effective URL `https://api.nfse.io/v2/...`), the same host used by the classic `product_invoices` resource
- **AND** no new base-URL constant SHALL be added to `Nfe::Configuration`, and the request SHALL NOT target `https://api.nfe.io`

#### Scenario: Classic product-invoice resource is unaffected

- **WHEN** the product RTC resource is added to the Client
- **THEN** `client.product_invoices` SHALL keep its existing method signatures and behavior unchanged

### Requirement: RTC product-invoice emission supports the discriminated 202 contract

`Nfe::Resources::ProductInvoicesRtc#create` SHALL accept keyword arguments `company_id:` and `data:`, where `data` is an `Nfe::Generated::ProductInvoiceRtcV1::ProductInvoiceRequest` value object or a `Hash`. It SHALL issue `POST /companies/{company_id}/productinvoices` and SHALL return either a `Nfe::Resources::ProductInvoiceRtcPending` (when the API responds HTTP 202 with a `Location` header) or a `Nfe::Resources::ProductInvoiceRtcIssued` (when the API responds HTTP 201 with the materialized invoice body).

The RTC layout SHALL be selected by the presence of the item-level `IBSCBS` group in the payload — there SHALL be no header or query parameter. This is the same endpoint the classic `product_invoices` resource uses. Emission SHALL be treated as asynchronous regardless of whether the API returns HTTP 201 or 202.

Both `#create` and `#create_with_state_tax` SHALL additionally accept an optional `idempotency_key:` keyword (sent as the `Idempotency-Key` HTTP header for safe retries) and an optional `request_options:` keyword (an `Nfe::RequestOptions` from `add-client-core`, threaded into the request to override `api_key`/`base_url`/`timeout` per call). POST SHALL NOT be auto-retried by the transport.

#### Scenario: Idempotency key forwarded as a header

- **WHEN** `create(company_id:, data:, idempotency_key: "product-rtc-42")` is called
- **THEN** the outgoing request SHALL carry the `Idempotency-Key: product-rtc-42` header
- **AND** when `idempotency_key:` is omitted, no `Idempotency-Key` header SHALL be sent

#### Scenario: Per-call request options override the Client defaults

- **WHEN** `create(company_id:, data:, request_options: Nfe::RequestOptions.new(api_key: "tenant-key", base_url: nil, timeout: nil))` is called
- **THEN** the request SHALL authenticate with `tenant-key` for that call only, without mutating the shared Client

#### Scenario: Async product emission returns a Pending result

- **WHEN** `client.product_invoices_rtc.create(company_id:, data:)` is called and the API responds HTTP 202 with `Location: /v2/companies/{company_id}/productinvoices/{invoice_id}`
- **THEN** the method SHALL return a `Nfe::Resources::ProductInvoiceRtcPending` whose `invoice_id` matches the final path segment of the `Location` header (extracted via `%r{productinvoices/([a-z0-9-]+)}i`)
- **AND** whose `location` matches the header value

#### Scenario: Immediate product emission returns an Issued result

- **WHEN** the API responds HTTP 201 with the invoice body
- **THEN** the method SHALL return a `Nfe::Resources::ProductInvoiceRtcIssued` whose `resource` returns a `Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource` hydrated from the response body

#### Scenario: 202 without a Location header raises a processing error

- **WHEN** the API responds HTTP 202 but omits the `Location` header
- **THEN** the SDK SHALL raise `Nfe::InvoiceProcessingError`

#### Scenario: No discriminator header or parameter is sent

- **WHEN** `create` is called with a payload carrying the item-level `IBSCBS` group
- **THEN** the serialized request SHALL select the RTC layout solely by payload shape
- **AND** no header or query parameter naming a `model`/`mod` or RTC flag SHALL be added to the request

### Requirement: Product RTC payload carries item-level IBS/CBS and IS tax groups

The product RTC payload SHALL carry the new RTC tax groups at the item level, on `InvoiceItemTaxResource` (`items[].tax`), alongside the legacy groups. The `IBSCBS` group (`IBSCBSTaxResource`) SHALL split IBS into a state sphere (`state` → `IBSStateTaxResource`) and a municipal sphere (`municipal` → `IBSMunicipalTaxResource`), with CBS (`cbs` → `CBSTaxResource`) being federal and carrying no state/municipal split. The `IS` group (`ISTaxResource`, Imposto Seletivo) SHALL be a product-only tax group with no equivalent on the NFS-e RTC payload.

#### Scenario: IBSCBS group present with state, municipal, and federal CBS

- **WHEN** `create` is called with an item carrying `items[].tax.IBSCBS`
- **THEN** the serialized `IBSCBS` group SHALL contain a `state` sub-group and a `municipal` sub-group for IBS, each exposing `rate` and `amount`
- **AND** it SHALL contain a single federal `cbs` sub-group with no state/municipal split

#### Scenario: Imposto Seletivo (IS) group present on the item

- **WHEN** `create` is called with an item carrying `items[].tax.IS`
- **THEN** the serialized `IS` group SHALL expose `situation_code`, `classification_code`, `basis`, `rate`, and `amount`
- **AND** the `IS` group SHALL be specific to the product RTC payload and absent from the NFS-e RTC payload

### Requirement: NF-e and NFC-e share one resource, distinguished by payload shape

`Nfe::Resources::ProductInvoicesRtc` SHALL emit both NF-e (modelo 55) and NFC-e (modelo 65) through the single `create` method and the single `POST /companies/{company_id}/productinvoices` endpoint. The two SHALL be distinguished by the shape of the payload — `print_type` (`PrintType`), `consumer_type`/`presence_type`, presence of `buyer`, and presence of `expected_delivery_on` — and SHALL NOT require a discriminator field on the request root nor a separate endpoint.

#### Scenario: NFC-e emitted via the same endpoint as NF-e

- **WHEN** `create` is called once with an NF-e payload (`print_type` an `NFe*` value, `buyer` present) and once with an NFC-e payload (`print_type` `DANFE_NFC_E`, `consumer_type`/`presence_type` set, no `buyer`)
- **THEN** both requests SHALL be issued to the same `POST /companies/{company_id}/productinvoices` endpoint on `https://api.nfse.io`
- **AND** neither request SHALL include a `model`/`mod` discriminator on the request root

### Requirement: Product RTC lifecycle methods

`Nfe::Resources::ProductInvoicesRtc` SHALL expose, carried over from the classic product surface on the same host and base path, the following methods: `create_with_state_tax(company_id:, state_tax_id:, data:)` issuing `POST /companies/{company_id}/statetaxes/{state_tax_id}/productinvoices`; `retrieve(company_id:, invoice_id:)`; `list(company_id:, environment:, ...)` with cursor pagination; `cancel(company_id:, invoice_id:, reason:)`; `list_items`; `list_events`; the file-resource downloads `download_pdf`, `download_xml`, `download_rejection_xml`, `download_epec_xml` (each returning a `Nfe::NfeFileResource` URI, matching the classic `ProductInvoices` contract and `nf-produto-v2.yaml` `FileResource{uri}`); the correction-letter methods `send_correction_letter`, `download_correction_letter_pdf`, `download_correction_letter_xml`; and the disablement methods `disable`, `disable_range`.

#### Scenario: Retrieve returns a typed InvoiceResource

- **WHEN** `retrieve(company_id:, invoice_id:)` succeeds
- **THEN** the return value SHALL be a `Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource` value object hydrated from the response body, exposing at least `flow_status`

#### Scenario: Retrieve of a missing invoice raises NotFoundError

- **WHEN** `retrieve(company_id:, invoice_id:)` receives HTTP 404
- **THEN** the SDK SHALL raise `Nfe::NotFoundError`

#### Scenario: List returns a paginated ListResponse

- **WHEN** `list(company_id:, environment:)` succeeds
- **THEN** the return value SHALL be a `Nfe::ListResponse` exposing the `product_invoices` page and cursor pagination (`starting_after`/`ending_before`/`limit`)

#### Scenario: Cancel is asynchronous and returns a cancellation resource

- **WHEN** `cancel(company_id:, invoice_id:, reason:)` is called
- **THEN** the SDK SHALL issue `DELETE /companies/{company_id}/productinvoices/{invoice_id}?reason=` and return a `RequestCancellationResource`

#### Scenario: Downloads return a file resource URI

- **WHEN** `download_pdf`, `download_xml`, `download_rejection_xml`, or `download_epec_xml` succeeds
- **THEN** the return value SHALL be a `Nfe::NfeFileResource` exposing a `uri` (matching the `FileResource{uri}` schema in `nf-produto-v2.yaml`), NOT raw `ASCII-8BIT` bytes
- **AND** this SHALL match the classic `ProductInvoices` download contract

#### Scenario: Disablement of a numbering range

- **WHEN** `disable_range(company_id:, data:)` is called
- **THEN** the SDK SHALL issue `POST /companies/{company_id}/productinvoices/disablement` with a `DisablementResource`-shaped body and return a `DisablementResource`

### Requirement: Fail-fast identifier validation on the product RTC resource

Every `ProductInvoicesRtc` method that takes a `company_id`, `invoice_id`, or `state_tax_id` SHALL validate it through `Nfe::IdValidator` (from `add-client-core`) before issuing any HTTP request, raising `Nfe::InvalidRequestError` synchronously on empty or whitespace-only values.

#### Scenario: Empty company ID rejected before HTTP

- **WHEN** any `ProductInvoicesRtc` method is called with an empty or whitespace-only `company_id`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` with a Portuguese-language message identifying the invalid argument
- **AND** no HTTP request SHALL be issued

#### Scenario: Empty state tax ID rejected before HTTP

- **WHEN** `create_with_state_tax` is called with an empty `state_tax_id`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` without issuing an HTTP request

### Requirement: Discriminated product RTC response classes

The SDK SHALL provide concrete, immutable response classes for product RTC invoice creation, implementing the `Pending` and `Issued` protocols defined in `add-client-core`:

- `Nfe::Resources::ProductInvoiceRtcPending` implementing `Pending` — exposing `invoice_id`, `location`, and the predicate `pending?` (returning `true`) / `issued?` (returning `false`)
- `Nfe::Resources::ProductInvoiceRtcIssued` implementing `Issued` — exposing `resource` typed at `Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource`, and the predicate `issued?` (returning `true`) / `pending?` (returning `false`)

#### Scenario: Discriminating product results with is_a?

- **WHEN** a consumer writes `if result.is_a?(Nfe::Resources::ProductInvoiceRtcPending) then ... else ... end`
- **THEN** the pending branch SHALL expose `invoice_id`/`location` and the issued branch SHALL expose `resource`
- **AND** the two classes SHALL be distinct from the classic `Nfe::Resources::ProductInvoicePending`/`Nfe::Resources::ProductInvoiceIssued` and from the NFS-e RTC response classes

#### Scenario: Discriminating product results with predicate methods

- **WHEN** a consumer receives the result of `create` and calls `result.pending?` / `result.issued?`
- **THEN** `Nfe::Resources::ProductInvoiceRtcPending#pending?` SHALL return `true` and `#issued?` SHALL return `false`
- **AND** `Nfe::Resources::ProductInvoiceRtcIssued#issued?` SHALL return `true` and `#pending?` SHALL return `false`

### Requirement: Product RTC DTOs are generated from the named OpenAPI schemas

The OpenAPI pipeline (from `add-openapi-pipeline`) SHALL sync `product-invoice-rtc-v1.yaml` from `nfeio-docs` and emit immutable `Data.define` value objects under `lib/nfe/generated/product_invoice_rtc_v1/` for the spec's named schemas, including `ProductInvoiceRequest`, `InvoiceResource`, `InvoiceItemTaxResource`, `IBSCBSTaxResource`, `IBSStateTaxResource`, `IBSMunicipalTaxResource`, `CBSTaxResource`, and `ISTaxResource`, plus corresponding `.rbs` signatures under `sig/`. Generated files SHALL NOT be hand-edited.

#### Scenario: ProductInvoiceRequest generated as an immutable value object

- **WHEN** the pipeline generates types from `product-invoice-rtc-v1.yaml`
- **THEN** `Nfe::Generated::ProductInvoiceRtcV1::ProductInvoiceRequest` SHALL exist as a `Data.define` value object exposing snake_case accessors
- **AND** `Nfe::Generated::ProductInvoiceRtcV1::IBSCBSTaxResource` SHALL exist exposing the `state`, `municipal`, and `cbs` sub-groups, and `Nfe::Generated::ProductInvoiceRtcV1::ISTaxResource` SHALL exist

#### Scenario: Generated product files carry the frozen-string-literal magic comment

- **WHEN** any file under `lib/nfe/generated/product_invoice_rtc_v1/` is generated
- **THEN** it SHALL start with `# frozen_string_literal: true`
