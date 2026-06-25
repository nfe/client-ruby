# release-tooling — Delta

## ADDED Requirements

### Requirement: Modern gemspec with zero runtime dependencies
The `nfe-io.gemspec` SHALL declare the gem name `nfe-io`, `required_ruby_version >= 3.2`, and SHALL NOT contain any runtime dependency (no `add_dependency`). It SHALL register only development dependencies (rspec, rubocop, steep, rbs, simplecov, rake). It SHALL set complete metadata including `homepage_uri`, `source_code_uri`, `changelog_uri`, `bug_tracker_uri`, `documentation_uri`, and `rubygems_mfa_required => "true"`. The packaged gem SHALL include the RBS signatures under `sig/`.

This requirement implements the release of the SDK built by `add-ruby-foundation`, `add-http-transport`, `add-openapi-pipeline`, `add-client-core`, `add-entity-resources`, `add-invoice-resources`, `add-rtc-invoice-emission`, and `add-lookup-resources`.

#### Scenario: Building the gem
- **WHEN** a maintainer runs `gem build nfe-io.gemspec`
- **THEN** the build SHALL produce `nfe-io-<version>.gem` without warnings, and `gem spec nfe-io-<version>.gem` SHALL report zero runtime dependencies

#### Scenario: Adding a runtime dependency
- **WHEN** a contributor proposes adding any non-stdlib package to the gem's runtime dependencies
- **THEN** the proposal SHALL require an explicit decision in a new OpenSpec change, because the SDK is committed to Ruby standard library only

#### Scenario: Installing on Ruby below 3.2
- **WHEN** a user runs `gem install nfe-io` on Ruby 3.1 or earlier
- **THEN** RubyGems SHALL refuse installation with a `required_ruby_version` error

#### Scenario: RBS shipped with the gem
- **WHEN** the gem is installed
- **THEN** the `sig/` directory containing the RBS signatures SHALL be present in the installed gem so consumers can type-check against it

### Requirement: Version is a single source of truth
The constant `Nfe::VERSION` in `lib/nfe/version.rb` SHALL be the single source of truth for the gem version. The gemspec SHALL read the version from this constant, and the release tooling SHALL update only this constant when bumping the version. For the v1 release the version SHALL be `1.0.0` (a major bump from the legacy `0.3.2`).

Git tags SHALL use the hyphenated prerelease form `vX.Y.Z` and `vX.Y.Z-rc.N`, but `Nfe::VERSION` and the published gem SHALL use the dotted prerelease form `X.Y.Z` and `X.Y.Z.rc.N` (RubyGems requires the dot). `scripts/release.sh` SHALL write the dotted form to `lib/nfe/version.rb` and create the hyphenated tag, and the release workflow SHALL assert that the built-gem version equals the dotted version derived from the tag.

#### Scenario: Gemspec reads the constant
- **WHEN** `gem build nfe-io.gemspec` runs
- **THEN** the produced gem's version SHALL equal the value of `Nfe::VERSION`, with no version literal duplicated elsewhere

#### Scenario: Frozen string literal header
- **WHEN** `lib/nfe/version.rb` is inspected
- **THEN** its first line SHALL be `# frozen_string_literal: true`, consistent with every `.rb` file in the project

#### Scenario: Hyphenated tag, dotted gem version
- **WHEN** the release script cuts a release candidate tagged `v1.0.0-rc.1`
- **THEN** it SHALL write `Nfe::VERSION = "1.0.0.rc.1"` (dotted) to `lib/nfe/version.rb` and create the annotated tag `v1.0.0-rc.1` (hyphenated)

#### Scenario: Workflow asserts version matches tag
- **WHEN** the release workflow runs for a pushed tag `vX.Y.Z-rc.N`
- **THEN** it SHALL derive the dotted version `X.Y.Z.rc.N` from the tag and assert the built-gem version (`Nfe::VERSION`) equals it, aborting the publish on any mismatch

### Requirement: CHANGELOG following Keep a Changelog
The repository SHALL include `CHANGELOG.md` written in Brazilian Portuguese, following the Keep a Changelog format and Semantic Versioning. It SHALL contain an `[Não lançado]` section at the top and a `[1.0.0]` entry documenting the greenfield rewrite categorized into `Adicionado`, `Alterado`, and `Removido`.

#### Scenario: Reading the changelog
- **WHEN** a user opens `CHANGELOG.md`
- **THEN** they SHALL find a `[1.0.0]` entry listing the new `Nfe::Client` API, the 17 resources, generated `Data.define` models, RBS signatures, the discriminated 202 contract, and the removal of the `rest-client` dependency and the global `Nfe.api_key` configuration

#### Scenario: Changelog rotation on release
- **WHEN** the release script cuts version `X.Y.Z`
- **THEN** the `[Não lançado]` section SHALL be rotated into a dated `[X.Y.Z] - YYYY-MM-DD` heading

### Requirement: Exhaustive migration guide from v0.3.x to v1.0.0
The repository SHALL include `MIGRATION.md` in Brazilian Portuguese documenting the complete migration from v0.3.x to v1.0.0, including:

- Gem version constraint change (`~> 0.3` → `~> 1.0`)
- Ruby version change (2.x → 3.2+)
- Configuration change from the global `Nfe.api_key("...")` setter method (and `Nfe.configure { |c| c.url = ... }`) to the instance `Nfe::Client.new(api_key:)`, the per-class `Nfe::ServiceInvoice.company_id("...")` pattern replaced by a per-call `company_id:` argument, plus automatic per-resource multi-host routing, the new `data_api_key:`, and `NFE_API_KEY`/`NFE_DATA_API_KEY` environment-variable fallback (explicit argument wins)
- Class-to-resource mapping for all 17 snake_case accessors
- Per-resource method mapping (old signature → new signature)
- Removal of the `rest-client` dependency and the resulting change from `RestClient::Exception` to the typed `Nfe::ApiConnectionError`/`Nfe::TimeoutError` hierarchy (`TimeoutError < ApiConnectionError`)
- The full typed error hierarchy table (`Nfe::Error` base with `AuthenticationError`, `AuthorizationError`, `InvalidRequestError`, `NotFoundError`, `ConflictError`, `RateLimitError`, `ServerError`, `ApiConnectionError`, `TimeoutError`, `SignatureVerificationError`, `ConfigurationError`, `InvoiceProcessingError`)
- The discriminated 202 `Pending`/`Issued` contract with a manual polling example
- Webhook signature verification migration
- Binary `String` downloads (`ASCII-8BIT`)
- The explicit list of features deferred from v1.0
- End-to-end examples for vanilla scripts and Rails

#### Scenario: A v0.3.x user migrating
- **WHEN** a developer using v0.3.x opens `MIGRATION.md`
- **THEN** they SHALL find a full mapping of their existing code to v1, plus at least one end-to-end example matching their integration pattern (vanilla script or Rails)

#### Scenario: Looking up a deferred feature
- **WHEN** a developer searches the document for `create_and_wait`, `create_batch`, or certificate upload
- **THEN** they SHALL find the deferred-features section explaining the absence and the manual workaround (e.g., polling via `Nfe::FlowStatus.terminal?`)

#### Scenario: Configuration migration
- **WHEN** a developer reads the configuration section
- **THEN** it SHALL show the v0.3.x global `Nfe.api_key("...")` setter method (and `Nfe.configure { |c| c.url = ... }`) replaced by `Nfe::Client.new(api_key: "...")`, the per-class `Nfe::ServiceInvoice.company_id("...")` replaced by a per-call `company_id:` argument, and SHALL explain that the base URL is no longer set globally but routed per resource

#### Scenario: Environment-variable fallback
- **WHEN** a developer constructs `Nfe::Client.new` without an explicit `api_key:`/`data_api_key:`
- **THEN** the documentation SHALL show `Configuration` reading `NFE_API_KEY` and `NFE_DATA_API_KEY` from the environment as a fallback, with an explicit constructor argument taking precedence over the environment value

### Requirement: Expanded README covering quickstart, resources, and patterns
The repository SHALL include an expanded `README.md` in Brazilian Portuguese covering installation, Ruby 3.2+ and zero-dependency requirements, a `Nfe::Client.new(api_key:)` quickstart, a resource map of all 17 accessors with host and key operations, a one-line example per resource, error handling, the 202 polling contract, configuration (timeout, retry, `data_api_key`, and `NFE_API_KEY`/`NFE_DATA_API_KEY` environment-variable fallback), a Sandbox vs Production section, binary downloads, and webhook signature verification.

#### Scenario: Consumer evaluating the SDK
- **WHEN** a developer opens `README.md`
- **THEN** they SHALL find a copy-pasteable quickstart, a table of all 17 resources mapped to their hosts and operations, and a configuration section documenting `api_key`, `data_api_key`, `environment`, `timeout`, and `retry`

#### Scenario: Environment-variable configuration
- **WHEN** a developer reads the configuration section
- **THEN** it SHALL document that `Configuration` reads `NFE_API_KEY` and `NFE_DATA_API_KEY` from the environment as a fallback, with an explicit constructor argument winning over the environment value

#### Scenario: Sandbox vs Production
- **WHEN** a developer reads the Sandbox vs Production section
- **THEN** it SHALL explain that the `Nfe::Client.new` `environment:` symbol selects a credential/key (not a URL, since host routing stays automatic per resource), how to obtain test credentials, and that `product_invoices`/`consumer_invoices` list and emission operations take a SEPARATE string `environment` parameter (`"Production"`/`"Test"`), including a Test-environment emission sample

#### Scenario: Webhook freshness warning
- **WHEN** a developer reads the README webhook section
- **THEN** it SHALL warn that a valid signature is NOT proof of freshness (NFE.io sends no anti-replay primitive), so handlers MUST be idempotent and deduplicate on the event/invoice id

#### Scenario: Versioning section
- **WHEN** a developer reads the versioning section
- **THEN** it SHALL state the SemVer policy and the RC/beta cadence, and link to `CHANGELOG.md` and `MIGRATION.md`

### Requirement: Contributing guide
The repository SHALL include `CONTRIBUTING.md` in Brazilian Portuguese documenting the branch policy (`master` active for v1, `0.x-legacy` frozen), local setup on Ruby 3.2+, the toolchain (`rake spec`, `rubocop`, `steep check`, `rake generate` / `rake generate:check`), the convention that every `.rb` file starts with `# frozen_string_literal: true`, the rule that generated files under `lib/nfe/generated/` are never hand-edited, and the release cadence.

#### Scenario: Contributor setting up
- **WHEN** a new contributor opens `CONTRIBUTING.md`
- **THEN** they SHALL find the commands to install dependencies, run the tests, lint, type-check, and regenerate code from the OpenAPI specs

#### Scenario: Editing generated code
- **WHEN** a contributor considers editing a file under `lib/nfe/generated/`
- **THEN** `CONTRIBUTING.md` SHALL instruct them to edit the OpenAPI spec and run `rake generate` instead, and SHALL note that CI fails via `rake generate:check` when the generated tree is out of sync

### Requirement: Runnable sample programs cover the main use cases
The repository SHALL ship a `samples/` directory containing runnable Ruby scripts covering the primary use cases of the SDK. Each script SHALL be self-contained, loadable via `samples/config.rb`, and documented in `samples/README.md`. A `samples/.env.example` SHALL be provided and `samples/.env` SHALL be git-ignored.

The minimum set of samples SHALL include:

- `service_invoice_issue.rb` (NFS-e emission + manual polling)
- `product_invoice_issue.rb` (NF-e emission)
- `consumer_invoice_issue.rb` (NFC-e emission)
- `company_crud.rb` (full CRUD of companies)
- `legal_person_create.rb` and `legal_person_update.rb`
- `webhook_verify.rb` (HMAC-SHA1 validation over raw body bytes)
- `cnpj_lookup.rb`
- `cpf_lookup.rb`
- `cep_lookup.rb`
- `tax_calculation.rb`
- `rtc_service_invoice.rb` (NFS-e RTC emission, depends on `add-rtc-invoice-emission`)

#### Scenario: Consumer evaluating the SDK
- **WHEN** a developer clones the repository and opens `samples/`
- **THEN** they SHALL find a runnable example for each major API category, plus a `.env.example` and `README.md` explaining setup

#### Scenario: Running a sample
- **WHEN** a developer configures `samples/.env` with valid sandbox credentials and runs `ruby samples/service_invoice_issue.rb`
- **THEN** the script SHALL execute end-to-end against the NFE.io sandbox and print the outcome (Pending or Issued)

#### Scenario: Download sample writes binary
- **WHEN** a sample downloads a PDF or XML
- **THEN** it SHALL write the result with `File.binwrite`, reinforcing the binary `String` (`ASCII-8BIT`) download contract

### Requirement: Single-command release preparation script
The repository SHALL provide `scripts/release.sh` that performs version bump, changelog rotation, commit, annotated tag, and push in a single interactive command, with `--dry-run`, `--skip-tests`, and `--skip-git` flags. The script SHALL NOT publish the gem itself — publication happens in the release workflow after the tag is pushed.

#### Scenario: Cutting a release on a clean branch
- **WHEN** a maintainer runs `scripts/release.sh` on the `master` branch with a clean working tree and green CI
- **THEN** the script SHALL prompt for a version, update `Nfe::VERSION`, rotate `CHANGELOG.md`, commit, create an annotated tag `vX.Y.Z`, and push the commit and tag to origin

#### Scenario: Dry-run rehearsal
- **WHEN** the maintainer runs `scripts/release.sh --dry-run`
- **THEN** the script SHALL print every step it would perform without modifying any file or invoking any git command with side effects

#### Scenario: Dirty working tree refusal
- **WHEN** the working tree has uncommitted changes and the script is invoked without `--skip-git`
- **THEN** the script SHALL refuse to proceed with an explanatory message

#### Scenario: Existing tag refusal
- **WHEN** the requested version corresponds to an existing git tag
- **THEN** the script SHALL fail early with a clear message before any change is made

#### Scenario: Invalid version format
- **WHEN** the maintainer types a version that does not match `X.Y.Z` or `X.Y.Z-rc.N` or `X.Y.Z-beta.N`
- **THEN** the script SHALL reject it and prompt again or exit

#### Scenario: No local gem push
- **WHEN** the release script completes successfully
- **THEN** it SHALL NOT have invoked `gem push`; the gem is published only by the release workflow triggered by the pushed tag

### Requirement: Release workflow gated on full CI, publishing to RubyGems
The repository SHALL include `.github/workflows/release.yml` triggered by pushes of tags matching `v*`. A `verify` job SHALL run the full CI gate — `rake spec` (with SimpleCov ≥ 80%), `rubocop`, `steep check`, and `rake generate:check` — across the Ruby 3.2/3.3/3.4 matrix. A `publish` job, depending on `verify`, SHALL build the gem and publish it to RubyGems, and SHALL create a GitHub Release.

#### Scenario: Tag push triggers verification then publish
- **WHEN** a tag `v1.0.0-rc.1` is pushed
- **THEN** GitHub Actions SHALL run the verification matrix, and only upon success SHALL the `publish` job build and push the gem and create the GitHub Release

#### Scenario: Failed verification aborts publish
- **WHEN** any job in the verification matrix fails for the tag
- **THEN** the gem SHALL NOT be published and no GitHub Release SHALL be created; the tag remains but the publish does not

#### Scenario: Generated code out of sync blocks release
- **WHEN** `rake generate:check` detects that `lib/nfe/generated/` or `sig/` is out of sync with `openapi/*.yaml`
- **THEN** the `verify` job SHALL fail and the release SHALL be aborted

### Requirement: RubyGems trusted publishing via OIDC
The `publish` job SHALL publish to RubyGems using trusted publishing via GitHub OIDC, granting the job `id-token: write` permission and obtaining an ephemeral credential, without storing a long-lived API key. When OIDC trusted publishing is not configured, the workflow SHALL fall back to a `GEM_HOST_API_KEY` sourced from the `RUBYGEMS_API_KEY` repository secret.

#### Scenario: Publishing with OIDC
- **WHEN** the `publish` job runs for a tag and the repository is registered as a trusted publisher on RubyGems
- **THEN** the job SHALL authenticate via OIDC and push the gem without any persistent API key

#### Scenario: Fallback to API key
- **WHEN** OIDC trusted publishing is not yet configured for the repository
- **THEN** the workflow SHALL use `GEM_HOST_API_KEY` from the `RUBYGEMS_API_KEY` secret to push the gem

### Requirement: Released gem is checksummed and MFA-protected
The `publish` job SHALL generate a SHA-256 checksum of the built `.gem` and attach both the `.gem` and its `.sha256` file to the GitHub Release. The gem SHALL declare `rubygems_mfa_required => "true"` so that interactive operations on the gem require multi-factor authentication.

#### Scenario: Checksum attached to release
- **WHEN** a release is published for tag `vX.Y.Z`
- **THEN** the GitHub Release SHALL include `nfe-io-X.Y.Z.gem` and `nfe-io-X.Y.Z.gem.sha256`, enabling independent verification of the artifact

#### Scenario: MFA required on the gem
- **WHEN** an account attempts a privileged operation on the `nfe-io` gem on RubyGems
- **THEN** RubyGems SHALL require multi-factor authentication because the gem metadata declares `rubygems_mfa_required`

### Requirement: AI skill for the Ruby SDK
The repository SHALL include `skills/nfeio-ruby-sdk/SKILL.md`, modeled on the Node SDK skill, with YAML front-matter (`name: nfeio-ruby-sdk` and a `description` of trigger conditions) and sections covering: gem/require, quickstart, a resource map of all 17 snake_case accessors, the discriminated 202 contract with manual polling, the typed error hierarchy, page-style vs cursor pagination, binary downloads, webhook signature verification, idiomatic Ruby pitfalls, and a decision tree. It SHALL include segmented `references/*.md` files.

#### Scenario: Agent invoked on NFE.io Ruby code
- **WHEN** an AI agent encounters code that requires `nfe` or references `Nfe::Client`, or a request about Brazilian fiscal documents in Ruby
- **THEN** the `nfeio-ruby-sdk` skill SHALL provide the resource map, the 202 contract guidance, and the error hierarchy needed to write correct code

#### Scenario: Reference files present
- **WHEN** the skill directory is inspected
- **THEN** it SHALL contain `references/service-invoices-and-polling.md`, `references/product-invoices-and-taxes.md`, `references/data-services-and-lookups.md`, `references/error-handling-and-patterns.md`, and `references/rtc-emission.md`

#### Scenario: Idioms adapted to Ruby
- **WHEN** the skill documents an SDK pattern
- **THEN** it SHALL use idiomatic Ruby (synchronous returns instead of Promises, binary `String` instead of Buffer, snake_case accessors, `Data.define` value objects, `is_a?`/`case in` instead of `instanceof`)

### Requirement: Webhook signature documentation uses the correct scheme
The README, MIGRATION guide, and AI skill SHALL document webhook signature verification as `X-Hub-Signature` with HMAC-SHA1 computed over the raw request body bytes, with a case-insensitive hex comparison, the `sha1=` prefix, and a timing-safe comparison. They SHALL warn that the legacy `X-NFe-Signature` + HMAC-SHA256 scheme found in some distribution docs is incorrect versus production. They SHALL also warn that a valid signature is NOT proof of freshness — NFE.io sends no anti-replay primitive — so handlers MUST be idempotent and deduplicate on the event/invoice id.

#### Scenario: Documenting signature verification
- **WHEN** a developer reads the webhook section in the README, MIGRATION, or skill
- **THEN** it SHALL instruct reading the raw body (`request.raw_post` in Rails, `request.body.read` in Rack) before JSON parsing, computing `OpenSSL::HMAC.hexdigest("SHA1", secret, raw_body)`, and comparing timing-safely against the `X-Hub-Signature` header value

#### Scenario: Warning about the wrong scheme
- **WHEN** a developer might otherwise copy the `X-NFe-Signature` + SHA-256 scheme from older distribution docs
- **THEN** the documentation SHALL explicitly flag that scheme as incorrect and direct them to HMAC-SHA1 with `X-Hub-Signature`

#### Scenario: Signature validity is not freshness
- **WHEN** a developer reads the webhook section in the README, MIGRATION, or skill
- **THEN** it SHALL state that a valid signature does not guarantee freshness (no anti-replay primitive is sent), and SHALL instruct that handlers be idempotent and deduplicate on the event/invoice id

### Requirement: RC and beta period before any GA release
The first stable `v1.0.0` release SHALL be preceded by at least one release candidate (`v1.0.0-rc.1` or later) published to RubyGems as a prerelease, followed by a beta period. During the beta period the `master` README SHALL display a banner indicating the in-development status; at the GA release the banner SHALL be removed, tied to the prerelease-vs-final flow of `scripts/release.sh` (a prerelease keeps the banner, a final release removes it). The README SHALL carry a one-line forward-compatibility note stating that `Pending`/`Issued` and `FlowStatus` are stable public API. Prerelease versions SHALL NOT be resolved as `latest` by RubyGems for consumers using a `~> 1.0` constraint.

#### Scenario: First v1.0.0 release
- **WHEN** the maintainer prepares to publish v1.0.0 for the first time
- **THEN** the workflow SHALL be: tag `v1.0.0-rc.1` → beta period → if no critical issues, tag `v1.0.0`

#### Scenario: Banner removed at GA
- **WHEN** the maintainer cuts the final `v1.0.0` (non-prerelease) via `scripts/release.sh`
- **THEN** the in-development banner SHALL be removed from the README, while a prerelease release SHALL leave it in place

#### Scenario: Critical issue during beta
- **WHEN** a critical issue is reported during the beta period
- **THEN** the maintainer SHALL fix it and tag `v1.0.0-rc.2`, restarting the beta clock

#### Scenario: Prerelease not auto-installed
- **WHEN** a consumer depends on `gem "nfe-io", "~> 1.0"` while only `v1.0.0-rc.1` is published
- **THEN** Bundler SHALL NOT resolve the prerelease unless the consumer opts in explicitly (e.g., `= 1.0.0.rc.1`)

#### Scenario: Patch release
- **WHEN** a patch release (`v1.0.1`) addresses a bug without API change
- **THEN** the maintainer MAY release directly without an RC/beta period, since the public surface is unchanged

### Requirement: Ruby SDK page in nfeio-docs
The existing live Ruby SDK page `docs/desenvolvedores/bibliotecas/ruby.md` in the `nfeio-docs` repository (the source of truth for API behavior) SHALL be updated: the incorrect `X-NFEIO-Signature` + Base64 webhook snippet and the global v0.3 `Nfe.api_key` examples SHALL be removed; a `Nfe::Client.new(api_key:)` quickstart SHALL be added; and the page SHALL mirror the Node SDK docs structure (migration, changelog, examples sections), with links to the README and MIGRATION guide. The SDK README SHALL link back to this documentation page.

#### Scenario: Docs page updated and linked
- **WHEN** a user browses the NFE.io documentation under "Bibliotecas → Ruby"
- **THEN** they SHALL find an installation and `Nfe::Client.new(api_key:)` quickstart page for the `nfe-io` gem — with the wrong `X-NFEIO-Signature` + Base64 webhook snippet and the global `Nfe.api_key` v0.3 examples removed — linking to the GitHub README and MIGRATION guide

#### Scenario: README links to docs
- **WHEN** a user reads the README's documentation section
- **THEN** it SHALL link to the Ruby SDK page in the NFE.io documentation
