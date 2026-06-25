# Project Context

## Purpose
This repository implements the official NFE.io Ruby SDK (gem `nfe-io`). It is undergoing a major modernization (v0.3.2 → v1.0.0): a **greenfield rewrite** that drops the old `rest-client`-based, Ruby 2.4-era codebase in favor of a stdlib-only, type-rigorous, OpenAPI-generated runtime with a small hand-written DX layer. Goals:
- Provide a modern, typed, **zero-runtime-dependency** SDK for Ruby 3.2+.
- Reach feature parity with the Node.js and PHP SDKs (the same 17-resource surface, parity-plus).
- Improve developer experience with a single client, typed errors, retry handling, immutable value objects, and comprehensive tests and docs.

The legacy v0.3.2 code is snapshotted to the frozen `0.x-legacy` branch; v1 is developed on `master`. Nothing from the legacy code is reused.

## Tech Stack
- Primary language: `Ruby` (>= 3.2)
- Runtime target: Ruby 3.2 / 3.3 / 3.4 (CI matrix)
- HTTP / crypto / IO: Ruby **standard library only** — `net/http`, `json`, `openssl`, `uri`, `securerandom`, `stringio`, `time`, `base64`. **No `rest-client`, `faraday`, or `httparty`.**
- Test runner: `RSpec`
- Coverage: `SimpleCov` (gate >= 80%)
- Type signatures: `RBS` (shipped under `sig/`)
- Type checker: `Steep`
- Lint/format: `RuboCop` (+ `rubocop-rspec`)
- OpenAPI tooling: a code generator (synced from `nfeio-docs`) that emits `Data.define` value objects under `lib/nfe/generated/` and `.rbs` signatures under `sig/nfe/generated/`.

## Project Conventions

### Code Style
- Every `.rb` file starts with `# frozen_string_literal: true` (enforced by RuboCop `Style/FrozenStringLiteralComment: always`).
- `snake_case` for methods, accessors, and file names; `CamelCase` for classes/modules.
- Public API uses **keyword arguments** (e.g. `Nfe::Client.new(api_key:)`).
- Domain models are immutable **`Data.define`** value objects — never `Struct`, `OpenStruct`, or `method_missing` dynamic objects.
- Downloads return a binary-safe `String` (`force_encoding(Encoding::ASCII_8BIT)`) — Ruby has no `Buffer`.
- All calls are **synchronous** (no Promises/async); the 202 contract is modeled as discriminated `Pending`/`Issued` value objects, and polling is a synchronous loop gated by `FlowStatus#terminal?`.
- Run `bundle exec rubocop` and satisfy all cops before committing.

### Architecture Patterns
- `lib/nfe/generated/` is the machine-generated OpenAPI output — **DO NOT EDIT**; corresponding signatures live in `sig/nfe/generated/`. All hand-written code lives outside `generated/`.
- Hand-written layers:
  - `lib/nfe/client.rb`: the single `Nfe::Client` (Stripe-style) with lazy, memoized `snake_case` resource accessors.
  - `lib/nfe/configuration.rb`: the **single source** of the multi-base-URL host map (`#base_url_for(family)`); no resource hard-codes a host.
  - `lib/nfe/http/`: a `Net::HTTP`-based HTTP client with retry, timeout, multipart, and binary download support (later change).
  - `lib/nfe/resources/`: the 17 resource classes, each constructed with the HTTP client for its host family.
  - `lib/nfe/errors/`: a typed error hierarchy (`Nfe::Error` base + `AuthenticationError`, `AuthorizationError`, `InvalidRequestError`, `NotFoundError`, `ConflictError`, `RateLimitError`, `ServerError`, `ApiConnectionError`, `TimeoutError`, `SignatureVerificationError`, `ConfigurationError`, `InvoiceProcessingError`).
- Multi-base-URL routing: each resource belongs to a host family (`main`, `addresses`, `nfe-query`, `legal-entity`, `natural-person`, `cte`). `Configuration#base_url_for(family)` resolves the host; unknown families fall back to `main` (`https://api.nfe.io/v1`).
- Most invoice/people endpoints are company-scoped (`company_id`).
- The 17 resources by group: **entity** (4) — `companies`, `legal_people`, `natural_people`, `webhooks`; **invoice** (5) — `service_invoices`, `product_invoices`, `consumer_invoices`, `transportation_invoices`, `inbound_product_invoices`; **lookup** (8) — `product_invoice_query`, `consumer_invoice_query`, `addresses`, `legal_entity_lookup`, `natural_person_lookup`, `tax_calculation`, `tax_codes`, `state_taxes`.

### Testing Strategy
- Unit specs under `spec/nfe/` exercise small modules and helpers.
- Integration specs simulate API behavior (including 202 async flows) with local stubs (no network).
- Coverage target: SimpleCov **>= 80%** line coverage; the gate fails the build below threshold (`SimpleCov.minimum_coverage 80`).
- Before merging: `bundle exec rspec && bundle exec rubocop && bundle exec steep check && bundle exec rbs validate` must pass.

### Git Workflow
- Branching: feature branches off `master`. Name branches `feat/`, `fix/`, `chore/`.
- Commits: conventional commit style (e.g. `feat(service-invoices): add create_and_wait`).
- Pull requests: include specs; update `CHANGELOG.md` for notable/breaking changes.
- CI runs only on `master` (v1); the `0.x-legacy` branch is frozen and unmonitored.

### Release & Versioning
- SemVer. v1 starts at `1.0.0`; the legacy line stays on `~> 0.3` (frozen, snapshotted on `0.x-legacy`).
- `Nfe::VERSION` lives in `lib/nfe/version.rb`.
- Releasing publishes `nfe-io` to RubyGems (separate release change); `rubygems_mfa_required` is set in the gemspec metadata.
- Packaged files include `lib/`, `sig/`, `README.md`, `MIGRATION.md`, `CHANGELOG.md`, and `LICENSE.txt`.

## Domain Context
- The SDK targets the NFE.io API for issuing and managing Brazilian electronic fiscal documents: NFS-e (service invoices), NF-e (product invoices), NFC-e (consumer invoices), CT-e (transportation), and inbound NF-e/CT-e distribution, plus lookups (CNPJ, CPF, address/CEP, tax calculation, tax codes, state taxes).
- Key domain concepts:
  - Most service/product invoice and people endpoints are scoped to a `company_id`.
  - Creating an invoice may return **HTTP 202** (async, with a `Location` header to poll) or **HTTP 201** (immediate, materialized body). The SDK returns discriminated `Pending`/`Issued` value objects; the invoice id is parsed from the `Location` header.
  - `FlowStatus` terminal states (`Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`) gate polling; non-terminal states keep polling.
  - Webhook signatures use **HMAC-SHA1** over the **raw request body bytes**, header `X-Hub-Signature`, format `sha1=<hex>` (uppercase on the wire, compared case-insensitively), timing-safe. (The legacy `X-NFe-Signature` + SHA-256 scheme in some distribuicao docs is incorrect — do not implement it.)
  - Company digital-certificate upload is a `multipart/form-data` POST of a PKCS#12 (A1, `.pfx`/`.p12`) file + password; validate with `OpenSSL::PKCS12` (real parse + password check), not a magic-byte heuristic.
  - RTC (Reforma Tributária do Consumo) adds IBS/CBS/IS tax groups; emission is selected by payload shape (presence of `ibs_cbs`), not a header — handled by dedicated RTC resources/specs in a later change.
- `nfeio-docs` (symlinked) is the **source of truth** for API behavior; the Node and PHP SDKs are the **reference** for SDK patterns and the resource surface.

## Important Constraints
- `lib/nfe/generated/` is auto-generated and must never be hand-edited.
- Minimum Ruby is **3.2** (`Data.define` requires it).
- **Zero runtime dependencies** in the published gem; development dependencies (rspec, rubocop, rbs, steep, simplecov) are allowed.
- No resource may hard-code a host URL — all routing goes through `Nfe::Configuration#base_url_for`.
- The v1 line breaks compatibility with v0.x; breaking changes are documented in `MIGRATION.md` and `CHANGELOG.md`.

## External Dependencies
- Upstream API hosts (resolved in `Configuration`): `https://api.nfe.io/v1` (main), `https://api.nfse.io` (cte/nfse families), `https://address.api.nfe.io/v2`, `https://nfe.api.nfe.io`, `https://legalentity.api.nfe.io`, `https://naturalperson.api.nfe.io`.
- OpenAPI spec files synced from `nfeio-docs` — used by the generation scripts (later change).

## Useful Files & Commands
- SDK sources: `lib/nfe/` (hand-written) and `lib/nfe/generated/` (auto-generated); signatures in `sig/` and `sig/nfe/generated/`.
- Core commands:
  - `bundle exec rspec` — run specs (with SimpleCov coverage gate)
  - `bundle exec rubocop` — lint/format
  - `bundle exec steep check` — type-check `lib/` against `sig/`
  - `bundle exec rbs validate` — validate RBS signatures
  - `bundle exec rake` — full quality gate (spec + rubocop + steep + rbs)
  - `gem build nfe-io.gemspec` — package the gem

## Contacts / Maintainers
- Maintained by the NFE.io team (suporte@nfe.io). See `README.md` and the gemspec `authors`/`metadata` for current ownership.
