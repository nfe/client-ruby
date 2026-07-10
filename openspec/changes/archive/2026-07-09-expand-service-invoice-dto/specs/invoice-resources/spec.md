# invoice-resources — Delta (expand-service-invoice-dto)

> Contexto: o retrieve de NFS-e devolve 44 campos (schema inline em
> `openapi/nf-servico-v1.yaml`, path `/v1/companies/{company_id}/serviceinvoices/{id}`);
> o DTO manuscrito cobre 19 e descarta o resto. Esta change adiciona `raw` +
> campos ISS tipados + Borrower com ponte Hash, como mitigação até o upstream
> componentizar a resposta. Espelha a change `expand-service-invoice-dto` do client-php.

## MODIFIED Requirements

### Requirement: Service invoice CRUD, email, downloads, and status
`ServiceInvoices` SHALL expose `create`, `list`, `retrieve`, `cancel`, `send_email`, `download_pdf`, `download_xml`, and `get_status`. Every method that takes a company ID or invoice ID SHALL validate it through `Nfe::IdValidator` (provided by `add-client-core`) before issuing the HTTP request. _(Requirement text unchanged — this delta only amends the retrieve scenario below; all other scenarios and the method table are preserved.)_

#### Scenario: Retrieve returns a typed model
- **WHEN** `retrieve(company_id:, invoice_id:)` succeeds
- **THEN** the return value SHALL be a typed invoice model (a generated model, or a hand-written `Nfe::ServiceInvoice` value object where the generated tree does not cover the shape) hydrated from the response body
- **AND** the hydrated model SHALL preserve the complete wire payload under its `raw` member, so no response field is inaccessible even when not covered by a typed member

## ADDED Requirements

### Requirement: ServiceInvoice value object covers the live retrieve shape via typed members plus raw
`Nfe::ServiceInvoice` SHALL expose the high-value fields of the NFS-e retrieve response as typed members — including the ISS tax trio `base_tax_amount`, `iss_rate`, `iss_tax_amount` — and SHALL preserve the complete wire payload under a `:raw` member populated by `from_api` (single hydration point covering list, retrieve, cancel, and the 201-issued path). New members are appended after the existing ones with `:raw` last. The ghost members `pdf` and `xml` (absent from the retrieve response — the documents come from the `/pdf` and `/xml` endpoints) SHALL remain but be marked `@deprecated` (YARD) pointing to `download_pdf`/`download_xml`. The `borrower` member SHALL be hydrated into `Nfe::ServiceInvoiceBorrower` (`Data.define`) with typed members (`id`, `name`, `federal_tax_number`, `email`, `phone_number`, `address`, `parent_id`) plus a `:raw` member, where `federal_tax_number` is normalized to `String` via `Company.stringify` (the spec declares `integer int64`, but the alphanumeric CNPJ — IN RFB 2.229/2024 — requires string tolerance), and SHALL keep Hash-style reads working by delegating `#[]` and `#dig` to `raw`. Contract source of truth: the OpenAPI spec (`openapi/nf-servico-v1.yaml`) plus live probes — never a sibling SDK.

#### Scenario: Unknown fields are preserved under raw
- **WHEN** `Nfe::ServiceInvoice.from_api` receives a payload containing fields without a typed member (e.g. the withholding tree `issAmountWithheld`/`irAmountWithheld`/..., `provider`, `taxationType`, `location`, `approximateTax`, `externalId`)
- **THEN** those fields SHALL be accessible through `invoice.raw` exactly as received
- **AND** `raw` SHALL be the complete payload, including fields that also have typed members

#### Scenario: ISS tax fields are typed
- **WHEN** the retrieve payload carries `baseTaxAmount`, `issRate`, and `issTaxAmount`
- **THEN** `invoice.base_tax_amount`, `invoice.iss_rate`, and `invoice.iss_tax_amount` SHALL return them as typed members

#### Scenario: Borrower is typed with a Hash-compatibility bridge
- **WHEN** the payload carries a `borrower` object
- **THEN** `invoice.borrower` SHALL be an `Nfe::ServiceInvoiceBorrower` with typed members, `federal_tax_number` returned as `String` (Integer or String on the wire)
- **AND** Hash-style reads SHALL keep working: `invoice.borrower["name"]` and `invoice.borrower.dig("address", "city")` delegate to the raw wire Hash

#### Scenario: Ghost members are deprecated, not removed
- **WHEN** the consumer reads `invoice.pdf` or `invoice.xml`
- **THEN** the members still exist (returning `nil` — the retrieve response has no such fields) and their YARD docs are `@deprecated`, pointing to `download_pdf`/`download_xml`

#### Scenario: Alignment test pins the contract by path
- **WHEN** the RSpec suite runs
- **THEN** an alignment spec SHALL parse the inline retrieve schema from `openapi/nf-servico-v1.yaml`, anchored by the path `/v1/companies/{company_id}/serviceinvoices/{id}` (NOT by `operationId` — `ServiceInvoices_idGet` collides between `/{id}` and `/external/{id}`)
- **AND** SHALL assert every typed member (except `raw`, `pdf`, `xml`) maps to a schema property, and the Borrower's typed members map to the `borrower` sub-schema
- **AND** SHALL pin the ghosts (`pdf`/`xml` absent from the schema) and the `borrower.federalTaxNumber` int64-vs-String deviation, so a spec sync that changes either fails the suite as a signal to revisit
- **AND** when the upstream componentizes the response (inline schema becomes a `$ref`), the path-anchored dig SHALL fail loudly as the signal to migrate to the generated model
