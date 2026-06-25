# lookup-resources Specification

## Purpose
TBD - created by archiving change add-lookup-resources. Update Purpose after archive.
## Requirements
### Requirement: Eight lookup, query, and state-tax resources are fully implemented
The SDK SHALL implement eight resource classes under `Nfe::Resources` — `Addresses`, `LegalEntityLookup`, `NaturalPersonLookup`, `ProductInvoiceQuery`, `ConsumerInvoiceQuery`, `TaxCalculation`, `TaxCodes`, and `StateTaxes` — each extending `Nfe::Resources::AbstractResource` (from `add-client-core`) and exposed as a lazy snake_case accessor on `Nfe::Client`. Method names, parameter order, and behavior SHALL match the NFE.io Node.js SDK 1:1, adapted to Ruby idioms (snake_case methods, keyword arguments, `Buffer`→binary `String`, `Promise`→synchronous return, `Date`/`Time`/`DateTime` accepted alongside `String` for date inputs).

This change depends on `add-client-core`, which owns the `Nfe::Configuration` host map, `Nfe::Resources::AbstractResource`, the base `Nfe::IdValidator` (`company_id`, `state_tax_id`, `access_key`), `Nfe::ListResponse`/`Nfe::ListPage`, the typed error classes, and the lazy resource accessors on `Nfe::Client`.

#### Scenario: Parity with the Node SDK
- **WHEN** comparing method signatures between this Ruby SDK and the Node SDK for any of the eight resources
- **THEN** they SHALL be 1:1 equivalent modulo Ruby idioms (e.g., `lookupByPostalCode` ⇄ `lookup_by_postal_code`, `Date`/`Time` accepted alongside ISO `String`)

#### Scenario: Accessing lookup resources from Client
- **WHEN** consumer code reads any of `client.addresses`, `client.legal_entity_lookup`, `client.natural_person_lookup`, `client.product_invoice_query`, `client.consumer_invoice_query`, `client.tax_calculation`, `client.tax_codes`, `client.state_taxes`
- **THEN** each accessor SHALL return a fully functional resource instance (not a stub that raises `NoMethodError`)

### Requirement: Multi-host routing for lookup endpoints
The SDK SHALL route each resource to its correct host as resolved by `Nfe::Configuration` from the resource's `api_family`. No resource SHALL hard-code a host. Six families exercised by this change resolve to dedicated hosts distinct from the default `https://api.nfe.io`:

| Resource | api_family | Host |
|---|---|---|
| `Addresses` | `addresses` | `https://address.api.nfe.io/v2` (the `/v2` is part of the base URL) |
| `LegalEntityLookup` | `legal-entity` | `https://legalentity.api.nfe.io` |
| `NaturalPersonLookup` | `natural-person` | `https://naturalperson.api.nfe.io` |
| `ProductInvoiceQuery` | `nfe-query` | `https://nfe.api.nfe.io` (paths use `v2`) |
| `ConsumerInvoiceQuery` | `nfe-query` | `https://nfe.api.nfe.io` (paths use `v1` + `/coupon/`) |
| `TaxCalculation`, `TaxCodes`, `StateTaxes` | `cte` | `https://api.nfse.io` |

#### Scenario: Address lookup routes to the address host with embedded version
- **WHEN** any method of `Nfe::Resources::Addresses` issues a request
- **THEN** the outgoing request URL SHALL begin with `https://address.api.nfe.io/v2/addresses` and SHALL NOT contain a duplicated version segment (no `/v2/v2`)

#### Scenario: Legal entity lookup routes to its dedicated host
- **WHEN** any method of `Nfe::Resources::LegalEntityLookup` issues a request
- **THEN** the outgoing request URL SHALL begin with `https://legalentity.api.nfe.io`

#### Scenario: Natural person lookup routes to its dedicated host
- **WHEN** any method of `Nfe::Resources::NaturalPersonLookup` issues a request
- **THEN** the outgoing request URL SHALL begin with `https://naturalperson.api.nfe.io`

#### Scenario: Both invoice queries share the nfe-query host
- **WHEN** a method of `Nfe::Resources::ProductInvoiceQuery` or `Nfe::Resources::ConsumerInvoiceQuery` issues a request
- **THEN** the outgoing request URL SHALL begin with `https://nfe.api.nfe.io`

#### Scenario: Tax and state-tax resources route to nfse.io
- **WHEN** a method of `Nfe::Resources::TaxCalculation`, `Nfe::Resources::TaxCodes`, or `Nfe::Resources::StateTaxes` issues a request
- **THEN** the outgoing request URL SHALL begin with `https://api.nfse.io`

### Requirement: Address lookup by postal code, search, and term
`Nfe::Resources::Addresses` SHALL expose:

- `lookup_by_postal_code(postal_code)` — accepts a CEP with or without hyphen; normalises to 8 digits via `Nfe::IdValidator.cep`; issues `GET /addresses/{cep}`
- `search(filter: nil)` — accepts an opaque OData `$filter` string forwarded verbatim as the `$filter` query parameter
- `lookup_by_term(term)` — accepts a non-empty search term; URL-encodes it; issues `GET /addresses/{encoded_term}`

Each method SHALL return an `AddressLookupResponse` value object.

#### Scenario: CEP with hyphen normalised
- **WHEN** `lookup_by_postal_code("01310-100")` is called
- **THEN** the request SHALL be issued to `/addresses/01310100` (digits only)

#### Scenario: CEP with invalid length rejected before HTTP
- **WHEN** `lookup_by_postal_code("123")` is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without issuing an HTTP request

#### Scenario: Search with OData filter forwarded opaquely
- **WHEN** `search(filter: "city eq 'São Paulo'")` is called
- **THEN** the SDK SHALL issue `GET /addresses` with the `$filter` query parameter set to the given expression (URL-encoded by the transport), without parsing or validating the expression

#### Scenario: Empty search term rejected
- **WHEN** `lookup_by_term("")` or `lookup_by_term("   ")` is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without issuing an HTTP request

### Requirement: Legal entity (CNPJ) lookup with four query methods
`Nfe::Resources::LegalEntityLookup` SHALL expose `get_basic_info(federal_tax_number, update_address: nil, update_city_code: nil)`, `get_state_tax_info(state, federal_tax_number)`, `get_state_tax_for_invoice(state, federal_tax_number)`, and `get_suggested_state_tax_for_invoice(state, federal_tax_number)`.

Each method SHALL normalise its inputs before issuing the request: CNPJ via `Nfe::IdValidator.cnpj` (14 digits, non-digits stripped) and state via `Nfe::IdValidator.state` (uppercase, validated against the 29-value set of 27 Brazilian UFs plus `EX` and `NA`).

#### Scenario: CNPJ with punctuation normalised
- **WHEN** `get_basic_info("12.345.678/0001-90")` is called
- **THEN** the SDK SHALL normalise to `12345678000190` and issue `GET /v2/legalentities/basicInfo/12345678000190`

#### Scenario: State in lowercase normalised to uppercase
- **WHEN** `get_state_tax_info("sp", "12345678000190")` is called
- **THEN** the SDK SHALL normalise the state to `SP` and issue `GET /v2/legalentities/stateTaxInfo/SP/12345678000190`

#### Scenario: Invalid state code rejected before HTTP
- **WHEN** `get_state_tax_info("XX", "12345678000190")` is called with a code outside the 29-value set
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without issuing an HTTP request

#### Scenario: Optional query parameters forwarded
- **WHEN** `get_basic_info("12345678000190", update_address: false, update_city_code: true)` is called
- **THEN** the SDK SHALL send `updateAddress=false` and `updateCityCode=true` as query parameters, and SHALL omit any option left at its default `nil`

#### Scenario: Suggested state tax uses the dedicated path
- **WHEN** `get_suggested_state_tax_for_invoice("SP", "12345678000190")` is called
- **THEN** the SDK SHALL issue `GET /v2/legalentities/stateTaxSuggestedForInvoice/SP/12345678000190`

### Requirement: Natural person (CPF) lookup with date normalisation
`Nfe::Resources::NaturalPersonLookup` SHALL expose `get_status(federal_tax_number, birth_date)` returning a `NaturalPersonStatusResponse`. The CPF SHALL be normalised via `Nfe::IdValidator.cpf` (11 digits). The `birth_date` SHALL accept either an ISO `String` (`YYYY-MM-DD`) or a `Date`/`Time`/`DateTime` object, normalised to `YYYY-MM-DD` via `Nfe::DateNormalizer.to_iso_date`. The request SHALL be `GET /v1/naturalperson/status/{cpf}/{birth_date}`.

#### Scenario: String birth date
- **WHEN** `get_status("12345678901", "1990-01-15")` is called
- **THEN** the SDK SHALL issue `GET /v1/naturalperson/status/12345678901/1990-01-15`

#### Scenario: Date object birth date and formatted CPF
- **WHEN** `get_status("123.456.789-01", Date.new(1990, 1, 15))` is called
- **THEN** the SDK SHALL normalise the CPF to `12345678901`, format the date as `1990-01-15`, and issue the same request as the string-date case

#### Scenario: Invalid birth date format rejected
- **WHEN** `get_status("12345678901", "15/01/1990")` is called (non-ISO format)
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without issuing an HTTP request

#### Scenario: Out-of-range birth date rejected
- **WHEN** `get_status("12345678901", "2026-13-45")` is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` (month 13 / day 45 fail the roundtrip)

### Requirement: Product invoice query by access key with downloads
`Nfe::Resources::ProductInvoiceQuery` SHALL expose `retrieve(access_key)`, `download_pdf(access_key)`, `download_xml(access_key)`, and `list_events(access_key)`, all keyed by a 44-digit access key normalised via `Nfe::IdValidator.access_key` and routed to `https://nfe.api.nfe.io` under API version `v2`. No company scope is required (read-only SEFAZ query). Download methods SHALL return raw bytes as a binary `String`.

#### Scenario: Retrieve by access key
- **WHEN** `retrieve("35261234...44 digits...")` is called with a valid access key
- **THEN** the SDK SHALL issue `GET https://nfe.api.nfe.io/v2/productinvoices/{access_key}` and return a `ProductInvoiceDetails` value object hydrated from the response

#### Scenario: Download PDF returns binary bytes
- **WHEN** `download_pdf(access_key)` is called
- **THEN** the SDK SHALL issue `GET /v2/productinvoices/{access_key}.pdf` with `Accept: application/pdf` and return a binary `String` whose first four bytes are `%PDF`

#### Scenario: Download XML returns binary bytes
- **WHEN** `download_xml(access_key)` is called
- **THEN** the SDK SHALL issue `GET /v2/productinvoices/{access_key}.xml` with `Accept: application/xml` and return a binary `String` whose first non-BOM character is `<`

#### Scenario: List events uses the events path
- **WHEN** `list_events(access_key)` is called
- **THEN** the SDK SHALL issue `GET /v2/productinvoices/events/{access_key}` and return a `ProductInvoiceEventsResponse`

#### Scenario: Access key with formatting normalised
- **WHEN** an access key is passed with spaces or dots
- **THEN** the SDK SHALL strip non-digit characters and validate the result has exactly 44 digits, raising `Nfe::InvalidRequestError` otherwise

### Requirement: Consumer invoice query by access key
`Nfe::Resources::ConsumerInvoiceQuery` SHALL expose `retrieve(access_key)` returning a `TaxCoupon` and `download_xml(access_key)` returning a binary `String`, routed to `https://nfe.api.nfe.io` under API version `v1` with the `/coupon/` path segment. This resource is the **read-only NFC-e/CFe-SAT lookup by access key** and is distinct from the `consumer_invoices` emission resource defined in `add-invoice-resources` (which is company-scoped and routes to `https://api.nfse.io`).

#### Scenario: Tax coupon retrieval
- **WHEN** `retrieve(access_key)` is called with a valid 44-digit access key
- **THEN** the SDK SHALL issue `GET https://nfe.api.nfe.io/v1/consumerinvoices/coupon/{access_key}` and return a `TaxCoupon` value object whose shape matches the Node SDK's canonical `TaxCoupon` (optional fields including `current_status`, `number`, `access_key`, `issued_on`, `issuer`, `buyer`, `totals`, `items`, `payment`)

#### Scenario: Tax coupon XML download
- **WHEN** `download_xml(access_key)` is called
- **THEN** the SDK SHALL issue `GET /v1/consumerinvoices/coupon/{access_key}.xml` with `Accept: application/xml` and return the raw XML bytes as a binary `String`

#### Scenario: Distinct from consumer invoice emission
- **WHEN** a consumer needs to emit an NFC-e rather than query one
- **THEN** they SHALL use `client.consumer_invoices` (from `add-invoice-resources`, host `https://api.nfse.io`), NOT `client.consumer_invoice_query` (host `https://nfe.api.nfe.io`)

### Requirement: Tax calculation with opaque request payload
`Nfe::Resources::TaxCalculation` SHALL expose `calculate(tenant_id, request)` returning a `CalculateResponse`. It SHALL `POST` to `/tax-rules/{tenant_id}/engine/calculate` (with `tenant_id` URL-encoded) on host `https://api.nfse.io`, forwarding `request` (a `Hash`) as the JSON body. The SDK SHALL validate only that `tenant_id` is non-empty, that `request` carries an `operation_type` (or `operationType`) field, and that `request[:items]` is a non-empty array; it SHALL NOT otherwise validate the request shape.

#### Scenario: Minimal calculation request
- **WHEN** `calculate("tenant-123", { operation_type: "Outgoing", issuer: {...}, recipient: {...}, items: [{ id: "1", ... }] })` is called
- **THEN** the SDK SHALL POST the body as JSON to `/tax-rules/tenant-123/engine/calculate` and hydrate the response into a `CalculateResponse`

#### Scenario: Empty items array rejected
- **WHEN** `calculate("tenant", { operation_type: "Outgoing", items: [] })` is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without issuing an HTTP request

#### Scenario: Empty tenant id rejected
- **WHEN** `calculate("", request)` is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without issuing an HTTP request

### Requirement: Tax codes listing with page-style pagination
`Nfe::Resources::TaxCodes` SHALL expose four parallel listing methods — `list_operation_codes`, `list_acquisition_purposes`, `list_issuer_tax_profiles`, and `list_recipient_tax_profiles` — each accepting `page_index:` (1-based) and `page_count:` keyword arguments, distinct from the cursor-style pagination used by `StateTaxes`. Each SHALL return a `TaxCodePaginatedResponse` carrying `current_page`, `total_pages`, `total_count`, and `items`. The paths SHALL be `/tax-codes/operation-code`, `/tax-codes/acquisition-purpose`, `/tax-codes/issuer-tax-profile`, and `/tax-codes/recipient-tax-profile` respectively, on host `https://api.nfse.io`.

#### Scenario: Default pagination defers to the API
- **WHEN** `list_operation_codes` is called with no arguments
- **THEN** the request SHALL omit `pageIndex` and `pageCount`, deferring to the API defaults

#### Scenario: Explicit 1-based pagination preserved
- **WHEN** `list_operation_codes(page_index: 2, page_count: 20)` is called
- **THEN** the request SHALL include `pageIndex=2` and `pageCount=20` (1-based preserved as the API expects)

#### Scenario: Each method targets its own path
- **WHEN** `list_acquisition_purposes`, `list_issuer_tax_profiles`, or `list_recipient_tax_profiles` is called
- **THEN** the SDK SHALL issue the request to `/tax-codes/acquisition-purpose`, `/tax-codes/issuer-tax-profile`, or `/tax-codes/recipient-tax-profile` respectively

### Requirement: State taxes full CRUD with body envelope
`Nfe::Resources::StateTaxes` SHALL expose `list`, `create`, `retrieve`, `update`, and `delete` for company state tax registrations (Inscrições Estaduais), routed to `https://api.nfse.io` under API version `v2`. `list` SHALL use cursor-style pagination (`starting_after:`, `ending_before:`, `limit:`). Both `create` and `update` SHALL wrap the request body as `{ stateTax: <data> }` to match the canonical Node SDK envelope. `company_id` and `state_tax_id` SHALL be validated via `Nfe::IdValidator`.

#### Scenario: Creating a state tax registration wraps the body
- **WHEN** `create(company_id, { tax_number: "123456789", serie: 1, number: 1, code: "SP" })` is called
- **THEN** the SDK SHALL `POST` to `https://api.nfse.io/v2/companies/{company_id}/statetaxes` with the body `{"stateTax": {"tax_number": "123456789", "serie": 1, ...}}` and return the created `NfeStateTax`

#### Scenario: Updating wraps the body the same way
- **WHEN** `update(company_id, state_tax_id, { serie: 2 })` is called
- **THEN** the SDK SHALL `PUT` to `/v2/companies/{company_id}/statetaxes/{state_tax_id}` with body `{"stateTax": {"serie": 2}}`

#### Scenario: Listing with cursor pagination
- **WHEN** `list(company_id, limit: 20)` is called
- **THEN** the SDK SHALL issue the `GET` and return an `Nfe::ListResponse` whose `page` carries the cursor metadata (`starting_after`/`ending_before`) and not `page_index`

#### Scenario: Deletion returns nil
- **WHEN** `delete(company_id, state_tax_id)` succeeds against HTTP 200 or 204
- **THEN** the method SHALL return `nil` without raising

#### Scenario: Empty company id rejected before HTTP
- **WHEN** any `StateTaxes` method receives an empty or whitespace-only `company_id`
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously without issuing an HTTP request

### Requirement: DateNormalizer helper
The SDK SHALL provide `Nfe::DateNormalizer` with a `to_iso_date(input)` method returning a `YYYY-MM-DD` `String`. It SHALL accept ISO date strings and `Date`/`Time`/`DateTime` objects, dropping any time component, and SHALL raise `Nfe::InvalidRequestError` for malformed or out-of-range inputs and for unsupported types. It SHALL depend only on the Ruby standard library (`date`, `time`).

#### Scenario: ISO string passthrough
- **WHEN** `Nfe::DateNormalizer.to_iso_date("1990-01-15")` is called
- **THEN** the method SHALL return `"1990-01-15"`

#### Scenario: Date/Time object conversion drops the time
- **WHEN** `Nfe::DateNormalizer.to_iso_date(Time.new(1990, 1, 15, 12, 34, 56))` is called
- **THEN** the method SHALL return `"1990-01-15"`

#### Scenario: Invalid format rejected
- **WHEN** `Nfe::DateNormalizer.to_iso_date("15/01/1990")` is called
- **THEN** the method SHALL raise `Nfe::InvalidRequestError`

#### Scenario: Out-of-range string rejected
- **WHEN** `Nfe::DateNormalizer.to_iso_date("2026-13-45")` is called
- **THEN** the method SHALL raise `Nfe::InvalidRequestError`

### Requirement: ID validators cover the lookup surface
`Nfe::IdValidator` SHALL expose `cep(value)`, `state(value)`, `cnpj(value)`, and `cpf(value)` validators in addition to the `company_id`, `state_tax_id`, and `access_key` validators provided by `add-client-core`. Each SHALL strip non-digit characters where appropriate, validate length (or membership for `state`), and return the normalised value, raising `Nfe::InvalidRequestError` (with a Portuguese-language message) on failure.

#### Scenario: CEP normalisation
- **WHEN** `Nfe::IdValidator.cep("01310-100")` is called
- **THEN** the method SHALL return `"01310100"` (8 digits)

#### Scenario: State validation rejects unknown codes
- **WHEN** `Nfe::IdValidator.state("ZZ")` is called with a code outside the 29-value set (27 UFs plus `EX` and `NA`)
- **THEN** the method SHALL raise `Nfe::InvalidRequestError`

#### Scenario: Special state codes EX and NA accepted
- **WHEN** `Nfe::IdValidator.state("ex")` or `Nfe::IdValidator.state("na")` is called
- **THEN** the method SHALL return the uppercase code (`"EX"` / `"NA"`) without raising

#### Scenario: CNPJ normalisation
- **WHEN** `Nfe::IdValidator.cnpj("12.345.678/0001-90")` is called
- **THEN** the method SHALL return `"12345678000190"` (14 digits)

#### Scenario: CPF normalisation
- **WHEN** `Nfe::IdValidator.cpf("123.456.789-01")` is called
- **THEN** the method SHALL return `"12345678901"` (11 digits)

### Requirement: Lookup responses are immutable value objects
Every response returned by a lookup resource (`AddressLookupResponse`, `LegalEntityBasicInfoResponse`, `LegalEntityStateTaxResponse`, `LegalEntityStateTaxForInvoiceResponse`, `NaturalPersonStatusResponse`, `ProductInvoiceDetails`, `ProductInvoiceEventsResponse`, `TaxCoupon`, `CalculateResponse`, `TaxCodePaginatedResponse`, `NfeStateTax`) SHALL be an immutable `Data.define` value object, hydrated from the response body. Where the OpenAPI generator covers the schema, the resource SHALL hydrate against the generated value object under `lib/nfe/generated/`; otherwise the SDK SHALL provide a hand-written value object under `lib/nfe/resources/dto/<family>/`. Generated files SHALL NOT be hand-edited.

#### Scenario: Hydrating a retrieve response
- **WHEN** `Nfe::Resources::ProductInvoiceQuery#retrieve` succeeds against the API
- **THEN** the return value SHALL be an immutable `Data.define` value object (generated or hand-written) whose attributes are populated from the response body

#### Scenario: Immutability of returned value objects
- **WHEN** consumer code attempts to mutate a returned value object's attribute
- **THEN** the attempt SHALL fail, because the value object is a frozen `Data.define` instance

