# client-core Specification

## Purpose
TBD - created by archiving change add-client-core. Update Purpose after archive.
## Requirements
### Requirement: Public Client class as the single entry point
The SDK SHALL expose `Nfe::Client` as the single primary entry point. Consumers SHALL instantiate it with at minimum an API key and obtain access to all SDK functionality through this object. The class SHALL be the public surface and SHALL NOT be designed for subclassing; customization SHALL be achieved by composing `Nfe::Configuration` and an injected transport.

#### Scenario: Minimal instantiation
- **WHEN** a consumer writes `Nfe::Client.new(api_key: "my-key")`
- **THEN** the object SHALL be ready to use with sensible defaults (production environment, default retry policy, default `Net::HTTP`-based transport)

#### Scenario: Instantiation with explicit configuration
- **WHEN** a consumer writes `Nfe::Client.new(configuration: Nfe::Configuration.new(api_key: "k", timeout: 120))`
- **THEN** the supplied `Nfe::Configuration` SHALL govern all subsequent requests and the convenience keyword arguments SHALL be ignored

#### Scenario: Missing all keys
- **WHEN** a consumer writes `Nfe::Client.new` with neither `api_key` nor `data_api_key` nor `configuration`, **and** neither `NFE_API_KEY` nor `NFE_DATA_API_KEY` is present in the environment
- **THEN** the SDK SHALL raise `Nfe::ConfigurationError` indicating that an API key is required

### Requirement: Typed Configuration with constructor validation
The SDK SHALL provide `Nfe::Configuration` carrying all configuration options: `api_key`, `data_api_key`, `environment`, `timeout`, `open_timeout`, `max_retries`, `logger`, `user_agent_suffix`, `base_url_overrides`, `ca_file`, `ca_path`, and `proxy`. Construction SHALL validate the inputs and SHALL raise `Nfe::ConfigurationError` on invalid values.

#### Scenario: Defaults applied
- **WHEN** a consumer writes `Nfe::Configuration.new(api_key: "k")`
- **THEN** `environment` SHALL default to `:production`, `max_retries` SHALL default to a non-negative integer, and `timeout`/`open_timeout` SHALL default to positive values

#### Scenario: Empty API key rejected
- **WHEN** a consumer writes `Nfe::Configuration.new(api_key: "")` with no `data_api_key` and no `NFE_API_KEY`/`NFE_DATA_API_KEY` in the environment
- **THEN** the constructor SHALL raise `Nfe::ConfigurationError`

#### Scenario: Data-only configuration is valid
- **WHEN** a consumer writes `Nfe::Configuration.new(data_api_key: "d")` with no `api_key`
- **THEN** the object SHALL construct successfully, deferring the main-key requirement until a main-family resource is accessed

#### Scenario: Invalid environment rejected
- **WHEN** a consumer writes `Nfe::Configuration.new(api_key: "k", environment: :sandbox)`
- **THEN** the constructor SHALL raise `Nfe::ConfigurationError`, since only `:production` and `:development` are accepted

### Requirement: Environment selects key, not URL
The SDK SHALL accept `environment` as one of `:production` (default) or `:development`. Both environments SHALL target the same API endpoints; the active environment SHALL be differentiated by the API key in use, not by a distinct base URL.

#### Scenario: Production and development share endpoints
- **WHEN** a consumer constructs a client with `environment: :development`
- **THEN** the resolved base URLs SHALL be identical to those used under `:production`, and only the API key SHALL differ in effect

### Requirement: Multi-base-URL host map is the single source of truth
`Nfe::Configuration` SHALL expose `base_url_for(family)` returning the correct host per NFE.io product family. This method SHALL be the only place that knows hosts; no resource SHALL hard-code a URL. The mapping SHALL be: `main` → `https://api.nfe.io`; `addresses` → `https://address.api.nfe.io/v2`; `nfe-query` → `https://nfe.api.nfe.io`; `legal-entity` → `https://legalentity.api.nfe.io`; `natural-person` → `https://naturalperson.api.nfe.io`; `cte` → `https://api.nfse.io`. An unknown family SHALL fall back to the `main` host.

#### Scenario: Main family resolution
- **WHEN** `base_url_for(:main)` (or an alias such as `:companies`, `:service_invoices`, `:legal_people`, `:natural_people`, `:webhooks`) is called
- **THEN** it SHALL return `https://api.nfe.io`

#### Scenario: Addresses host embeds the version
- **WHEN** `base_url_for(:addresses)` is called
- **THEN** it SHALL return `https://address.api.nfe.io/v2`, where the `/v2` is part of the base URL and not the resource path

#### Scenario: CT-e family resolution
- **WHEN** `base_url_for(:cte)` (or an alias such as `:transportation`, `:inbound_product`, `:product_invoices`, `:consumer_invoices`, `:tax_calculation`, `:tax_codes`, `:state_taxes`) is called
- **THEN** it SHALL return `https://api.nfse.io`

#### Scenario: Query and lookup hosts
- **WHEN** `base_url_for(:nfe_query)`, `base_url_for(:legal_entity)`, and `base_url_for(:natural_person)` are called
- **THEN** they SHALL return `https://nfe.api.nfe.io`, `https://legalentity.api.nfe.io`, and `https://naturalperson.api.nfe.io` respectively

#### Scenario: Unknown family falls back to main
- **WHEN** `base_url_for(:something_unknown)` is called
- **THEN** it SHALL return `https://api.nfe.io`

#### Scenario: Per-family override
- **WHEN** a `Configuration` is built with `base_url_overrides: { cte: "https://staging.example" }` and `base_url_for(:cte)` is called
- **THEN** it SHALL return `https://staging.example`, taking precedence over the default map

### Requirement: API key resolution per family (two-key model)
`Nfe::Configuration` SHALL expose `api_key_for(family)`. Data-services families (`addresses`, `legal-entity`, `natural-person`, `nfe-query`) SHALL use `data_api_key` when present and SHALL fall back to `api_key` otherwise. All other families SHALL use `api_key`. When the resolved key is `nil` at the time a resource is accessed, the SDK SHALL raise `Nfe::ConfigurationError`.

#### Scenario: Data family uses data key
- **WHEN** a configuration has both `api_key` and `data_api_key` set and `api_key_for(:addresses)` is called
- **THEN** it SHALL return the `data_api_key`

#### Scenario: Data family falls back to main key
- **WHEN** a configuration has only `api_key` set and `api_key_for(:nfe_query)` is called
- **THEN** it SHALL return the `api_key`

#### Scenario: Main family always uses main key
- **WHEN** `api_key_for(:main)` is called on a configuration that also has a `data_api_key`
- **THEN** it SHALL return the `api_key`, never the `data_api_key`

### Requirement: Configuration keys fall back to environment variables
`Nfe::Configuration` SHALL resolve `api_key` from the `NFE_API_KEY` environment variable and `data_api_key` from the `NFE_DATA_API_KEY` environment variable as a FALLBACK. An explicit constructor argument SHALL always win over the environment value (resolution order: explicit argument, then environment). The "at least one key provided" validation SHALL run after this fallback is applied.

#### Scenario: API key read from environment
- **WHEN** `NFE_API_KEY` is set in the environment and a consumer writes `Nfe::Configuration.new` with no explicit `api_key`
- **THEN** the configuration SHALL adopt the `NFE_API_KEY` value as its `api_key`

#### Scenario: Data API key read from environment
- **WHEN** `NFE_DATA_API_KEY` is set in the environment and a consumer writes `Nfe::Configuration.new` with no explicit `data_api_key`
- **THEN** the configuration SHALL adopt the `NFE_DATA_API_KEY` value as its `data_api_key`

#### Scenario: Explicit argument wins over environment
- **WHEN** `NFE_API_KEY` is set in the environment and a consumer writes `Nfe::Configuration.new(api_key: "explicit")`
- **THEN** the configuration SHALL use `"explicit"` and SHALL ignore the environment value

### Requirement: TLS trust can only be added, never disabled
`Nfe::Configuration#ca_file` (and optionally `#ca_path`) SHALL be the ONLY override of the TLS trust store, and it SHALL only be able to ADD or replace a CA bundle used to verify the peer. The SDK SHALL NOT expose any public API to set `OpenSSL::SSL::VERIFY_NONE` or otherwise disable peer verification (no `insecure_ssl` flag). The upstream `insecureSsl` attribute is a server-side property of a webhook delivery target and SHALL NOT be confused with the SDK's outbound TLS configuration. `Nfe::Configuration#proxy`, when set, SHALL be passed through to the underlying `Net::HTTP` proxy configuration.

#### Scenario: Custom CA bundle is honored
- **WHEN** a `Configuration` is built with `ca_file: "/path/to/corporate-ca.pem"`
- **THEN** the transport SHALL use that bundle to verify the server certificate while STILL performing full peer verification

#### Scenario: Peer verification cannot be disabled
- **WHEN** a consumer searches the public `Nfe::Configuration` and `Nfe::Client` surface for a way to disable certificate verification
- **THEN** no public option SHALL set `VERIFY_NONE` or an `insecure_ssl` mode, and peer verification SHALL remain enabled on every request

### Requirement: Seventeen lazy snake_case resource accessors
`Nfe::Client` SHALL expose at least the following seventeen core resource accessors, each a snake_case method that lazily constructs and memoizes its resource on first read. Opt-in additive changes (e.g. `add-rtc-invoice-emission`) MAY register further accessors on top of these seventeen. The accessors SHALL be: `service_invoices`, `product_invoices`, `consumer_invoices`, `transportation_invoices`, `inbound_product_invoices`, `product_invoice_query`, `consumer_invoice_query`, `companies`, `legal_people`, `natural_people`, `webhooks`, `addresses`, `legal_entity_lookup`, `natural_person_lookup`, `tax_calculation`, `tax_codes`, and `state_taxes`. This surface matches the PHP SDK 1:1 — parity-plus over the 16-resource Node SDK: the Ruby/PHP surface adds the 17th resource, `consumer_invoices` (NFC-e emission), which the Node SDK does not expose.

#### Scenario: Accessing a resource accessor
- **WHEN** consumer code reads `client.service_invoices`
- **THEN** it SHALL return an instance of the corresponding resource class (a subclass of `Nfe::Resources::AbstractResource`)

#### Scenario: Memoization
- **WHEN** consumer code reads `client.companies` twice
- **THEN** both reads SHALL return the same object identity (the resource SHALL be constructed once and cached)

#### Scenario: All seventeen core accessors present
- **WHEN** the seventeen accessor names are enumerated against `Nfe::Client`
- **THEN** each SHALL be a defined public method; these seventeen form the core resource surface, and no additional **core** accessor SHALL exist beyond them (opt-in extension changes MAY register further accessors, such as `service_invoices_rtc` and `product_invoices_rtc` from `add-rtc-invoice-emission`)

#### Scenario: Data-only client serves data resources
- **WHEN** a client constructed with only `data_api_key` reads `client.addresses`
- **THEN** the resource SHALL be usable without raising, because the addresses family resolves the data key

#### Scenario: Main resource without main key raises on access
- **WHEN** a client constructed with only `data_api_key` reads `client.companies` and issues a request
- **THEN** the SDK SHALL raise `Nfe::ConfigurationError`, because the main family has no resolvable key

### Requirement: Lazy resource accessors are thread-safe
A single `Nfe::Client` instance SHALL be safe to share across threads. The lazy, memoized resource accessors SHALL guard their memoization with a `Mutex` so that concurrent first reads of the same accessor construct the resource exactly once and never race. This makes a shared `Client` safe under Rails, Sidekiq, and Puma. (The per-origin keep-alive connection pool is guarded by its own `Mutex` in `add-http-transport`.)

#### Scenario: Concurrent first read returns one instance
- **WHEN** many threads read `client.companies` for the first time concurrently on a shared `Nfe::Client`
- **THEN** every thread SHALL observe the same single resource instance and no duplicate resource SHALL be constructed by a race

### Requirement: AbstractResource provides HTTP and hydration helpers
The SDK SHALL define `Nfe::Resources::AbstractResource`, constructed with the owning `Nfe::Client`. It SHALL provide protected helpers `get`, `post`, `put`, and `delete` that build requests through the client's transport for the resource's declared family, plus `full_path`, `hydrate`, `download`, `hydrate_list`, and `handle_async_response`. Each subclass SHALL declare its `api_family` and (optionally) `api_version`.

#### Scenario: Subclass issues a request
- **WHEN** a resource whose `api_family` is `:cte` calls `get("/v2/companies/x/productinvoices")`
- **THEN** the outgoing request SHALL target `https://api.nfse.io` (resolved via `base_url_for(:cte)`) with the family's resolved API key applied

#### Scenario: full_path with a version
- **WHEN** a resource with `api_version` `"v1"` calls `full_path("/companies/x")`
- **THEN** the result SHALL be `/v1/companies/x`

#### Scenario: full_path with an empty version
- **WHEN** a resource with an empty `api_version` (e.g., the addresses resource, whose host embeds `/v2`) calls `full_path("/addresses/01310100")`
- **THEN** the result SHALL be `/addresses/01310100` with no doubled leading slash

#### Scenario: hydrate produces an immutable value object
- **WHEN** `hydrate(SomeDto, payload)` is called with a payload hash
- **THEN** it SHALL return an immutable `Data.define` value object produced by the generated DTO's factory (e.g., `SomeDto.from_api(payload)`)

### Requirement: Downloads return raw bytes as a binary-safe String
`AbstractResource#download(path)` SHALL return the response body as a Ruby `String` whose encoding is `Encoding::ASCII_8BIT` (binary-safe), so binary documents (PDF/XML/ZIP) are not corrupted by transcoding. The caller decides whether to persist (e.g., `File.binwrite`) or stream the bytes.

#### Scenario: PDF download is binary-safe
- **WHEN** `download("/.../pdf")` succeeds against the API
- **THEN** the return value SHALL be a `String` with encoding `ASCII-8BIT` whose first four bytes are `%PDF`

#### Scenario: XML download is binary-safe
- **WHEN** `download("/.../xml")` succeeds
- **THEN** the return value SHALL be a `String` with encoding `ASCII-8BIT` containing the raw XML bytes

### Requirement: Discriminated 202 contract with Pending and Issued results
The SDK SHALL define `Nfe::Pending` (a `Data.define` exposing `invoice_id` and `location`) and `Nfe::Issued` (a `Data.define` exposing `resource`). `AbstractResource#handle_async_response` SHALL return `Nfe::Pending` for an HTTP 202 response carrying a `Location` header, and `Nfe::Issued` (wrapping a hydrated DTO) for an HTTP 201/200 response with a body. Consumers SHALL discriminate the result with `is_a?`/`case`.

#### Scenario: Async 202 yields Pending
- **WHEN** `handle_async_response` receives an HTTP 202 with `Location: /v1/companies/x/serviceinvoices/abc-123`
- **THEN** it SHALL return an `Nfe::Pending` whose `invoice_id` is `abc-123` (parsed from the final path segment) and whose `location` is the header value

#### Scenario: Immediate 201 yields Issued
- **WHEN** `handle_async_response` receives an HTTP 201 with the materialized invoice body
- **THEN** it SHALL return an `Nfe::Issued` whose `resource` is the DTO hydrated from the response body

#### Scenario: 202 without Location is a protocol violation
- **WHEN** `handle_async_response` receives an HTTP 202 with no `Location` header
- **THEN** the SDK SHALL raise `Nfe::InvoiceProcessingError` describing the missing header

#### Scenario: Discriminating the result
- **WHEN** consumer code branches on `result.is_a?(Nfe::Pending)`
- **THEN** the pending branch SHALL expose `invoice_id`/`location` and the other branch SHALL expose `resource`

### Requirement: FlowStatus terminal-state helper
The SDK SHALL provide `Nfe::FlowStatus.terminal?(status)` returning `true` for `"Issued"`, `"IssueFailed"`, `"Cancelled"`, and `"CancelFailed"`, and `false` for all other values. The method SHALL accept either a `String` or a `Symbol`. This helper enables manual polling loops in the absence of an automatic polling helper.

#### Scenario: Terminal status
- **WHEN** `Nfe::FlowStatus.terminal?("Issued")`, `"IssueFailed"`, `"Cancelled"`, or `"CancelFailed"` is called
- **THEN** the method SHALL return `true`

#### Scenario: Non-terminal status
- **WHEN** `Nfe::FlowStatus.terminal?("WaitingDefineRpsNumber")` (or any of `PullFromCityHall`, `WaitingCalculateTaxes`, `WaitingSend`, `WaitingSendCancel`, `WaitingReturn`, `WaitingDownload`) is called
- **THEN** the method SHALL return `false`

#### Scenario: Unknown status
- **WHEN** `Nfe::FlowStatus.terminal?("Whatever")` is called
- **THEN** the method SHALL return `false`

### Requirement: ListResponse accommodates page-style and cursor-style pagination
The SDK SHALL provide `Nfe::ListResponse` carrying `data` (a list of hydrated DTOs) and `page` (`Nfe::ListPage`). `Nfe::ListPage` SHALL expose `page_index`, `page_count`, `starting_after`, `ending_before`, and `total`, all optional, so each resource populates the half relevant to its endpoint. `AbstractResource#hydrate_list(klass, payload, wrapper_key:)` SHALL unwrap `payload[wrapper_key]`, hydrate each item, and build the appropriate `ListPage`.

#### Scenario: Page-style listing
- **WHEN** a resource paginates with `page_index`/`page_count` (e.g., service invoices, companies, tax codes)
- **THEN** the returned `ListResponse.page` SHALL have `page_index` and `page_count` set and the cursor fields `nil`

#### Scenario: Cursor-style listing
- **WHEN** a resource paginates with `starting_after`/`ending_before` (e.g., product invoices, consumer invoices, state taxes)
- **THEN** the returned `ListResponse.page` SHALL have the cursor fields set and `page_index` `nil`

#### Scenario: Data is uniform across shapes
- **WHEN** a consumer reads `result.data` regardless of pagination shape
- **THEN** it SHALL be a list of hydrated DTOs accessible identically in both cases

### Requirement: ID and access-key validators run before HTTP
The SDK SHALL provide `Nfe::IdValidator` with methods `company_id`, `invoice_id`, `access_key`, `state_tax_id`, `event_key`, `cnpj`, `cpf`, `cep`, and `state`. Each validator SHALL run client-side and SHALL raise `Nfe::InvalidRequestError`, with a Portuguese-language message identifying the invalid argument, before any HTTP request is issued. `access_key` SHALL accept formatted input, strip non-digit characters, validate the result against `/\A\d{44}\z/`, and return the normalized string. `cnpj` SHALL normalize and validate format without coercing to Integer, so that future alphanumeric CNPJ (v3) input is not corrupted.

#### Scenario: Empty company ID rejected synchronously
- **WHEN** `Nfe::IdValidator.company_id("")` is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError` synchronously, without making an HTTP request, with a pt-BR message

#### Scenario: Access key with formatting is normalized
- **WHEN** `Nfe::IdValidator.access_key("3526 1234 ... (44 digits with separators)")` is called
- **THEN** it SHALL return a 44-character digits-only string and SHALL NOT raise

#### Scenario: Access key of wrong length rejected
- **WHEN** `Nfe::IdValidator.access_key("123")` is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError`

#### Scenario: CNPJ is not coerced to Integer
- **WHEN** `Nfe::IdValidator.cnpj("12.345.678/0001-90")` is called
- **THEN** it SHALL return a normalized `String` of digits and SHALL NOT return or rely on an Integer

#### Scenario: Invalid state rejected
- **WHEN** `Nfe::IdValidator.state("ZZ")` is called
- **THEN** the SDK SHALL raise `Nfe::InvalidRequestError`

### Requirement: Resource registry maps each accessor to the correct host
Each of the seventeen resource stubs SHALL declare an `api_family` such that, through `Configuration#base_url_for`, it resolves to the canonical host for that product. The five families involved SHALL be: `main` (service_invoices, companies, legal_people, natural_people, webhooks), `cte` (product_invoices, consumer_invoices, transportation_invoices, inbound_product_invoices, tax_calculation, tax_codes, state_taxes), `nfe-query` (product_invoice_query, consumer_invoice_query), `addresses` (addresses), `legal-entity` (legal_entity_lookup), and `natural-person` (natural_person_lookup).

#### Scenario: Each accessor resolves its expected host
- **WHEN** a resource's declared `api_family` is resolved via `base_url_for`
- **THEN** the host SHALL match the canonical map (e.g., `transportation_invoices` → `https://api.nfse.io`, `addresses` → `https://address.api.nfe.io/v2`, `legal_entity_lookup` → `https://legalentity.api.nfe.io`)

#### Scenario: Stub method raises until filled by a resource change
- **WHEN** consumer code calls a business method on an unfilled resource stub
- **THEN** the SDK SHALL raise `NotImplementedError` naming the change that implements the resource (e.g., `add-invoice-resources`)

### Requirement: Low-level request escape hatch
`Nfe::Client` SHALL expose an internal method to issue an arbitrary request against any family, allowing consumers and resources to call endpoints not yet wrapped by a resource. It SHALL resolve the family's host and key and apply the standard authorization and User-Agent headers.

#### Scenario: Calling an unwrapped endpoint
- **WHEN** a consumer calls `client.request(:get, family: :main, path: "/v1/some/new/endpoint")`
- **THEN** the SDK SHALL issue the request to `https://api.nfe.io/v1/some/new/endpoint` with the main key and standard headers, returning the raw response

### Requirement: Per-call request options for multi-tenant overrides
The SDK SHALL define `Nfe::RequestOptions` as an immutable `Data.define` carrying optional `api_key`, `base_url`, and `timeout`. `Nfe::Client#request` SHALL accept an optional `request_options:` keyword, and when present its non-nil fields SHALL override the family-resolved `api_key`, `base_url`, and `timeout` for that single call; nil fields SHALL fall back to the normal family resolution. `Nfe::Resources::AbstractResource` SHALL accept and thread an optional `request_options:` through its helpers to `Nfe::Client#request`, and resource methods (at least the emission methods) SHALL accept it. This enables a multi-tenant per-call `api_key` without constructing a second `Client`.

#### Scenario: Per-call api_key overrides the family key
- **WHEN** a caller passes `request_options: Nfe::RequestOptions.new(api_key: "tenant-key")` to a request on a `Client` configured with a different `api_key`
- **THEN** that single request SHALL authenticate with `"tenant-key"` while other requests continue to use the client's configured key

#### Scenario: Nil fields fall back to family resolution
- **WHEN** a caller passes `Nfe::RequestOptions.new(timeout: 90)` with `api_key` and `base_url` left nil
- **THEN** only the timeout SHALL be overridden for that call and the `api_key`/`base_url` SHALL resolve normally from the family

#### Scenario: Two tenants share one client
- **WHEN** two requests on the same `Client` each pass a distinct `request_options.api_key`
- **THEN** each request SHALL use its own tenant key, with no second `Client` instance required

### Requirement: User-Agent carries the SDK version
The transport SHALL build a `User-Agent` header from `Nfe::VERSION`, optionally appending `user_agent_suffix` when configured.

#### Scenario: Version in User-Agent
- **WHEN** any request is issued
- **THEN** the `User-Agent` header SHALL include the `Nfe::VERSION` string

#### Scenario: Integrator suffix appended
- **WHEN** the client is configured with `user_agent_suffix: "my-app/2.1"`
- **THEN** the `User-Agent` header SHALL include both the SDK version and `my-app/2.1`

### Requirement: createAndWait and polling helper are deferred past 1.0
The SDK v1.0 SHALL NOT implement `create_and_wait`, `create_batch`, or a `poll_until_complete` helper on the client or any resource. The discriminated `Nfe::Pending`/`Nfe::Issued` contract plus `Nfe::FlowStatus.terminal?` SHALL be sufficient for writing manual polling loops, and these helpers are explicitly deferred to a future release without breaking the public contract.

#### Scenario: Looking for an automatic polling helper
- **WHEN** consumer code references `client.poll_until_complete(...)` or a resource's `create_and_wait(...)` against v1.0
- **THEN** Ruby SHALL raise `NoMethodError`, since the method is not defined

#### Scenario: Manual polling is documented
- **WHEN** v1.0 documentation describes polling
- **THEN** it SHALL show a manual loop using `result.is_a?(Nfe::Pending)`, `retrieve`, and `Nfe::FlowStatus.terminal?` until a terminal state is reached

