# sdk-foundation Specification

## Purpose
TBD - created by archiving change add-ruby-foundation. Update Purpose after archive.
## Requirements
### Requirement: Minimum Ruby version
The SDK SHALL declare a minimum Ruby runtime of 3.2 via `required_ruby_version` and SHALL NOT support Ruby versions below 3.2.

#### Scenario: Installing on Ruby 3.1
- **WHEN** a user runs `gem install nfe-io` (or `bundle install`) on Ruby 3.1
- **THEN** RubyGems SHALL refuse installation with a `required_ruby_version` constraint error

#### Scenario: Installing on Ruby 3.2 or above
- **WHEN** a user installs the gem on Ruby 3.2, 3.3, or 3.4
- **THEN** RubyGems SHALL install the package successfully

### Requirement: Gem name and version
The SDK SHALL be published on RubyGems under the unchanged name `nfe-io`, and the version constant `Nfe::VERSION` SHALL be `"1.0.0"` (a major bump from the legacy `0.3.2`).

#### Scenario: Installing the SDK
- **WHEN** a user runs `gem install nfe-io`
- **THEN** the package SHALL resolve to this repository's tagged v1 releases under the same gem name as the legacy line

#### Scenario: Reading the version constant
- **WHEN** a consumer reads `Nfe::VERSION`
- **THEN** it SHALL return the string `"1.0.0"`

### Requirement: Root module namespace
The SDK SHALL expose all public classes under the `Nfe` Ruby module and SHALL be requirable via `require "nfe"`.

#### Scenario: Requiring the entrypoint
- **WHEN** a consumer writes `require "nfe"`
- **THEN** the constant `Nfe::Client` SHALL be defined without any additional `require`

#### Scenario: File location and namespace alignment
- **WHEN** a class `Nfe::Configuration` is defined
- **THEN** the file SHALL be located at `lib/nfe/configuration.rb`

### Requirement: frozen_string_literal magic comment in every source file
Every Ruby source file under `lib/` and `sig/`-adjacent tooling SHALL declare `# frozen_string_literal: true` as its first line.

#### Scenario: A source file missing the magic comment
- **WHEN** a contributor adds a file `lib/nfe/foo.rb` without `# frozen_string_literal: true` as the first line
- **THEN** CI (RuboCop cop `Style/FrozenStringLiteralComment` with `EnforcedStyle: always`) SHALL fail the build

### Requirement: Zero runtime dependencies
The gemspec SHALL declare no runtime dependencies (no `add_dependency` calls) and the SDK SHALL rely exclusively on the Ruby standard library: `net/http`, `json`, `openssl`, `uri`, `securerandom`, `stringio`, `time`, and `base64`.

#### Scenario: Inspecting the built gem
- **WHEN** the gem is built and its dependencies inspected (`gem specification nfe-io dependencies`)
- **THEN** the runtime dependency list SHALL be empty (development dependencies excluded)

#### Scenario: Proposing a runtime dependency
- **WHEN** a contributor proposes adding a gem to the runtime dependencies (not development dependencies)
- **THEN** the proposal SHALL require an explicit design decision in a new OpenSpec change

#### Scenario: rest-client removed
- **WHEN** the v1 gemspec is inspected
- **THEN** it SHALL NOT depend on `rest-client` (the legacy v0.3.2 runtime dependency)

### Requirement: Single client entrypoint with lazy resource accessors
The SDK SHALL expose a single client constructed via `Nfe::Client.new(api_key:, data_api_key: nil, environment: :production, base_url: nil, timeout: 30, retry_config: nil)` using keyword arguments, and SHALL provide lazy, memoized, `snake_case` accessors for all 17 resources.

#### Scenario: Constructing the client
- **WHEN** a consumer calls `Nfe::Client.new(api_key: "sk_test_...")`
- **THEN** the method SHALL return a client instance without raising, and without eagerly instantiating any resource or HTTP client

#### Scenario: All 17 resource accessors are present
- **WHEN** a consumer reads each of `service_invoices`, `product_invoices`, `consumer_invoices`, `transportation_invoices`, `inbound_product_invoices`, `product_invoice_query`, `consumer_invoice_query`, `companies`, `legal_people`, `natural_people`, `webhooks`, `addresses`, `legal_entity_lookup`, `natural_person_lookup`, `tax_calculation`, `tax_codes`, and `state_taxes` on the client
- **THEN** each accessor SHALL be defined and SHALL return a resource object (not raise `NoMethodError`)

#### Scenario: Accessor naming is snake_case
- **WHEN** the public accessor for the Node SDK's `serviceInvoices` / PHP's `serviceInvoices` is referenced
- **THEN** it SHALL be named `service_invoices` (idiomatic Ruby snake_case), and likewise `legal_entity_lookup`, `natural_person_lookup`, `inbound_product_invoices`, etc.

#### Scenario: Lazy memoized instantiation
- **WHEN** a consumer reads `client.companies` twice
- **THEN** the same resource instance SHALL be returned on both reads (memoized on first access)

#### Scenario: Instance state replaces global API key
- **WHEN** two clients are constructed with different API keys
- **THEN** each client SHALL hold its own credentials as instance state, with no shared global `@@api_key`

### Requirement: Configuration is the single source of the multi-base-URL host map
The SDK SHALL resolve API host base URLs exclusively through `Nfe::Configuration`, exposing a lookup (e.g. `#base_url_for(family)`) for the six host families, and no resource SHALL hard-code a host URL.

#### Scenario: Resolving each host family
- **WHEN** `base_url_for` is queried for each family
- **THEN** it SHALL return: `main` → `https://api.nfe.io` (the `/v1` segment is supplied by the resource `api_version`, not baked into the host); `addresses` → `https://address.api.nfe.io/v2` (documented exception: the `/v2` is part of the base URL); `nfe-query` → `https://nfe.api.nfe.io`; `legal-entity` → `https://legalentity.api.nfe.io`; `natural-person` → `https://naturalperson.api.nfe.io`; `cte` → `https://api.nfse.io`

#### Scenario: Unknown family falls back to main
- **WHEN** `base_url_for` is queried for a family not in the map
- **THEN** it SHALL return the `main` host `https://api.nfe.io` as a safe default (the `/v1` segment is supplied by the resource `api_version`)

#### Scenario: No resource hard-codes a URL
- **WHEN** the `lib/nfe/` source tree is searched for literal host strings outside `lib/nfe/configuration.rb`
- **THEN** no resource file SHALL contain a hard-coded `https://*.nfe.io` or `https://api.nfse.io` host

### Requirement: Generated models are immutable value objects isolated from hand-written code
The SDK SHALL emit OpenAPI-derived models as immutable `Data.define` value objects under `lib/nfe/generated/`, with corresponding RBS signatures under `sig/nfe/generated/`, and these generated files SHALL NEVER be hand-edited.

#### Scenario: Generated tree is isolated
- **WHEN** the code generator runs
- **THEN** it SHALL write value objects only under `lib/nfe/generated/` and signatures only under `sig/nfe/generated/`, leaving hand-written code untouched

#### Scenario: Value objects are immutable
- **WHEN** a generated model is instantiated and a consumer attempts to mutate one of its attributes
- **THEN** the object SHALL be immutable (a `Data.define` instance has no attribute writers)

#### Scenario: Generated code is excluded from lint
- **WHEN** RuboCop runs
- **THEN** `lib/nfe/generated/**/*` SHALL be excluded from linting because the files are generated, not hand-written

### Requirement: Immutable domain models use Data.define
Hand-written domain models and value objects SHALL be defined with `Data.define` (Ruby 3.2+) using keyword construction, replacing any dynamic `method_missing`-based object from the legacy code.

#### Scenario: A value object is immutable and comparable
- **WHEN** two `Data.define`-based value objects are built with equal attributes
- **THEN** they SHALL be `==` to each other and SHALL expose no attribute setters

### Requirement: FlowStatus terminal states gate polling
The SDK SHALL define a `FlowStatus` concept whose terminal states are exactly `Issued`, `IssueFailed`, `Cancelled`, and `CancelFailed`, with a predicate (e.g. `terminal?`) used to gate polling loops; non-terminal states include `PullFromCityHall`, `WaitingCalculateTaxes`, `WaitingDefineRpsNumber`, `WaitingSend`, `WaitingSendCancel`, `WaitingReturn`, and `WaitingDownload`.

#### Scenario: Terminal status detection
- **WHEN** `terminal?` is evaluated for `Issued`, `IssueFailed`, `Cancelled`, or `CancelFailed`
- **THEN** it SHALL return `true`

#### Scenario: Non-terminal status detection
- **WHEN** `terminal?` is evaluated for `WaitingSend` (or any other non-terminal state)
- **THEN** it SHALL return `false`

### Requirement: Downloads return binary-safe Strings
The SDK SHALL document and require that all raw-bytes download methods return a `String` whose encoding is forced to `Encoding::ASCII_8BIT` (binary-safe), since Ruby has no `Buffer` type.

#### Scenario: PDF download encoding
- **WHEN** a download method returns raw PDF or XML bytes
- **THEN** the returned `String` SHALL have encoding `ASCII-8BIT` so the bytes are preserved without transcoding

### Requirement: Synchronous discriminated 202 result contract
The SDK SHALL model the create contract synchronously (no async/Promises): a creation call SHALL return a `Pending` result (HTTP 202 with a `Location` header) or an `Issued` result (HTTP 201 with the materialized body) as distinct value objects.

#### Scenario: Async creation yields Pending
- **WHEN** a create endpoint responds HTTP 202 with a `Location` header
- **THEN** the SDK SHALL return a `Pending` result object carrying the location and the extracted invoice id (no Promise)

#### Scenario: Immediate creation yields Issued
- **WHEN** a create endpoint responds HTTP 201 with the resource body
- **THEN** the SDK SHALL return an `Issued` result object carrying the hydrated value object (no Promise)

### Requirement: Type rigor via RBS, Steep, and RuboCop
The SDK SHALL ship RBS signatures under `sig/`, type-check with Steep, and lint with RuboCop, all enforced in CI.

#### Scenario: RBS signatures are shipped in the gem
- **WHEN** the gem is built
- **THEN** `sig/**/*.rbs` SHALL be included in the packaged files

#### Scenario: Running the type checker
- **WHEN** a contributor runs `bundle exec steep check`
- **THEN** Steep SHALL type-check `lib/` against the signatures in `sig/` and report zero errors for the foundation artifacts

#### Scenario: Validating the signatures
- **WHEN** a contributor runs `bundle exec rbs validate`
- **THEN** the RBS signatures under `sig/` SHALL validate successfully

### Requirement: Test suite with coverage gate
The SDK SHALL test with RSpec and SHALL enforce a SimpleCov line-coverage minimum of 80%, failing the build below that threshold.

#### Scenario: Running the test suite
- **WHEN** a contributor runs `bundle exec rspec`
- **THEN** RSpec SHALL execute the specs under `spec/` with SimpleCov measuring coverage

#### Scenario: Coverage below the gate fails the build
- **WHEN** measured line coverage is below 80%
- **THEN** SimpleCov SHALL cause the process to exit non-zero, failing CI

### Requirement: Development tooling
The gemspec SHALL declare development dependencies on `rake`, `rspec`, `rubocop`, `rubocop-rspec`, `rbs`, `steep`, and `simplecov`, and the `Rakefile` SHALL expose tasks for `spec`, `rubocop`, `steep`, and `rbs`.

#### Scenario: Default rake task runs the full quality gate
- **WHEN** a contributor runs `bundle exec rake`
- **THEN** the default task SHALL run RSpec, RuboCop, Steep, and RBS validation

### Requirement: CI matrix across supported Ruby versions
The repository SHALL run continuous integration via GitHub Actions against Ruby 3.2, 3.3, and 3.4 on every push and pull request to the `master` branch, running RSpec, RuboCop, Steep, and `rbs validate`, with the SimpleCov >= 80% gate.

#### Scenario: Pushing to master
- **WHEN** a commit is pushed to `master`
- **THEN** GitHub Actions SHALL run `rspec`, `rubocop`, `steep check`, and `rbs validate` for each Ruby version in the matrix (3.2, 3.3, 3.4)

#### Scenario: CI ignores the legacy branch
- **WHEN** a commit is pushed to `0.x-legacy`
- **THEN** the v1 CI workflow SHALL NOT run against it

### Requirement: Branch and version policy
The `master` branch SHALL host all v1 development. The legacy v0.3.2 (rest-client based) codebase SHALL be snapshotted to a frozen `0.x-legacy` branch that receives no maintenance.

#### Scenario: Consumer choosing the legacy line
- **WHEN** a consumer pins `gem "nfe-io", "~> 0.3"`
- **THEN** the resolved release line SHALL be the frozen v0.x code (snapshotted on `0.x-legacy`), which receives no further updates

#### Scenario: Consumer choosing v1
- **WHEN** a consumer pins `gem "nfe-io", "~> 1.0"`
- **THEN** the resolved release line SHALL be the v1 code developed on `master`

### Requirement: Greenfield rewrite reuses no legacy code
The v1 SDK SHALL NOT import, copy, or adapt any file from the legacy `lib/nfe/*` tree (e.g. `nfe_object.rb`, `api_resource.rb`, `api_operations/*`, the global `@@api_key` configuration); `lib/nfe/` SHALL be authored clean.

#### Scenario: No legacy artifacts in v1
- **WHEN** the v1 `lib/nfe/` tree is inspected
- **THEN** it SHALL contain no `method_missing`-based dynamic object, no `rest-client` usage, and no module-level global API key state

### Requirement: License retained as MIT
The SDK SHALL retain the MIT license, declared as `spec.license = "MIT"` and shipped as a license file in the gem.

#### Scenario: License declaration
- **WHEN** the gemspec is inspected
- **THEN** `spec.license` SHALL be `"MIT"` and the license file SHALL be present in the repository

### Requirement: Migration documentation stub
The repository SHALL include a `MIGRATION.md` documenting the v0.x → v1 breaking changes, including the entrypoint change from `Nfe.api_key(...)` to `Nfe::Client.new(api_key:)`, removal of `rest-client`, the move to immutable value objects, and a statement that the legacy line receives no backports.

#### Scenario: Migration guide present
- **WHEN** a consumer upgrading from v0.x opens `MIGRATION.md`
- **THEN** it SHALL describe the new client entrypoint, the zero-runtime-dependency change, and the no-backport policy for the `0.x-legacy` branch

