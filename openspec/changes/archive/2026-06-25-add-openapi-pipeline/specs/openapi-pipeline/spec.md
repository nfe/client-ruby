# openapi-pipeline — Delta

## ADDED Requirements

### Requirement: A Ruby code generator reads OpenAPI specs and emits typed value objects
The SDK SHALL provide `scripts/generate.rb`, a Ruby script runnable as `ruby scripts/generate.rb` (no Node, Java, or external generator), that discovers every `*.yaml`/`*.json` spec under `openapi/`, loads each, compiles its `components.schemas`, and emits Ruby code under `lib/nfe/generated/` and matching RBS signatures under `sig/nfe/generated/`.

The generator SHALL emit **types only** — value objects and enums — and SHALL NOT emit clients, resources, factories, HTTP code, polling, or pagination. Those are hand-written by the resource changes (depende de `add-ruby-foundation`; consumed by `add-invoice-resources`).

#### Scenario: Running the generator
- **WHEN** a developer runs `ruby scripts/generate.rb` (or `rake generate`) against the `openapi/` directory
- **THEN** the generator SHALL write one `.rb` file per `object`/`enum` schema under `lib/nfe/generated/<family>/` and one matching `.rbs` file under `sig/nfe/generated/<family>/`, and SHALL print the count of files written

#### Scenario: Types only, no service surface
- **WHEN** the generator finishes
- **THEN** no client, resource, factory, HTTP, polling, or pagination code SHALL appear under `lib/nfe/generated/` — only `Data.define` value objects, enum constant modules, and the generated marker

### Requirement: Generation has zero runtime dependencies
The generated code under `lib/nfe/generated/` SHALL be pure Ruby standard library (`Data.define`, frozen constants) with no `require` of any external gem. All generation-time dependencies SHALL be confined to a dev-only `:codegen` Gemfile group and SHALL NOT appear as `add_dependency` in `nfe-io.gemspec`.

#### Scenario: Published gem carries no codegen dependency
- **WHEN** the gem is installed for runtime use (e.g., `bundle install --without codegen`)
- **THEN** the generated value objects SHALL load and function with only the Ruby standard library, and no codegen dependency SHALL be present

#### Scenario: YAML parsing uses the standard library
- **WHEN** the generator parses a spec file
- **THEN** it SHALL use `psych` from the Ruby standard library (Ruby 3.2+) as the primary YAML parser, avoiding an external YAML gem

### Requirement: Generated value objects are immutable Data.define classes
Each OpenAPI `object` schema SHALL be emitted as an immutable `Data.define` value object in the namespace `Nfe::Generated::<Family>`, with one attribute per schema property and snake_case attribute names. Generated models SHALL be anemic — attributes only, no business logic.

#### Scenario: Object schema becomes a Data.define
- **WHEN** the generator processes an `object` schema named `Borrower` with properties `name` and `federalTaxNumber`
- **THEN** it SHALL emit `Nfe::Generated::<Family>::Borrower = Data.define(:name, :federal_tax_number, ...)` whose instances are frozen, with the original property name preserved in a comment

#### Scenario: camelCase property maps to snake_case attribute
- **WHEN** a property is named `federalTaxNumber` in the spec
- **THEN** the generated `Data.define` attribute SHALL be `:federal_tax_number` and the original `federalTaxNumber` SHALL be recorded in a comment for hydration traceability

### Requirement: Enum schemas become frozen constant modules
Each schema declaring `enum: [...]` SHALL be emitted as a Ruby `module` of frozen constants plus an `ALL` array, rather than loose symbols or an external enum gem. The generator SHALL support both String-backed and Integer-backed enums.

#### Scenario: String enum
- **WHEN** the generator processes a schema with `enum: ["Issued", "Cancelled"]`
- **THEN** it SHALL emit a module exposing `Issued = "Issued"`, `Cancelled = "Cancelled"`, and `ALL = [Issued, Cancelled].freeze`

#### Scenario: Non-enum schema returns no enum
- **WHEN** the enum compiler is given an `object` schema with no `enum` key
- **THEN** it SHALL return `nil` (the schema is compiled as a `Data.define` instead)

### Requirement: Generator emits matching RBS signatures alongside Ruby code
For every generated `.rb` value object or enum module, the generator SHALL emit a matching `.rbs` signature under `sig/nfe/generated/<family>/` in the same pass, derived from the same internal model, so the hand-written surface can type-check against generated types with Steep (per `add-ruby-foundation`).

#### Scenario: RBS mirrors the value object
- **WHEN** the generator emits `Nfe::Generated::NfServicoV1::Borrower = Data.define(...)`
- **THEN** it SHALL also emit `sig/nfe/generated/nf_servico_v1/borrower.rbs` declaring the class, its typed attributes, and the constructor signature

#### Scenario: No drift between code and signature
- **WHEN** a property's type or nullability changes in the spec and the generator is re-run
- **THEN** both the `.rb` attribute and the `.rbs` type SHALL update together (single internal model), with no manual `.rbs` edit required

### Requirement: Each generated DTO carries a from_api hydration class method
The generator SHALL emit a `from_api(payload)` class method on every generated `Data.define` value object. `from_api` SHALL map camelCase JSON keys from the API payload to the value object's snake_case members, SHALL drop unknown keys (keys with no matching member), and SHALL recurse into nested object and array attributes — hydrating each referenced (`$ref`) object into its own DTO via that DTO's `from_api`, and each element of a `$ref` array into the item DTO. Primitive and free-form (`Hash`) attributes SHALL be assigned as-is. `from_api` SHALL be the only generated method on the otherwise anemic value object (no business logic). The generator SHALL emit a matching `.rbs` signature for `from_api`.

The `from_api` call site lives in the hand-written resource/client layer (`klass.from_api(payload)`), but the producer of the method and its `.rbs` is this pipeline.

#### Scenario: camelCase payload keys map to snake_case members
- **WHEN** `from_api({"federalTaxNumber" => 123, "name" => "Acme"})` is called on a DTO with members `:federal_tax_number` and `:name`
- **THEN** it SHALL return an instance with `federal_tax_number == 123` and `name == "Acme"`

#### Scenario: Unknown payload fields are dropped
- **WHEN** the payload contains a key with no matching value-object member (e.g., a field the spec did not declare)
- **THEN** `from_api` SHALL ignore that key and construct the instance without raising, so payloads with extra/forward-compatible fields hydrate cleanly

#### Scenario: Nested object attribute is hydrated into its DTO
- **WHEN** a DTO has an attribute typed as a `$ref` to another generated DTO and the payload supplies a nested object for it
- **THEN** `from_api` SHALL recurse, calling the referenced DTO's `from_api` on the nested object, so the attribute holds a hydrated DTO instance rather than a raw `Hash`

#### Scenario: Nested array of refs is hydrated element-by-element
- **WHEN** a DTO has an attribute typed as an array of a `$ref` item type and the payload supplies an array of objects
- **THEN** `from_api` SHALL map each element through the item DTO's `from_api`, yielding an `Array` of hydrated DTO instances

#### Scenario: from_api signature is emitted in RBS
- **WHEN** the generator emits a value object with `from_api`
- **THEN** the matching `.rbs` SHALL declare a `def self.from_api: (Hash[String, untyped] payload) -> instance` signature so the hand-written layer type-checks the hydration call

### Requirement: Type mapping translates OpenAPI types to idiomatic Ruby and RBS
The generator SHALL map OpenAPI schema fragments to Ruby attributes and RBS types as follows: `string`→`String`, `integer`→`Integer`, `number`→`Float`, `boolean`→`bool`, free-form `object`→`Hash[String, untyped]`, `array` with `items`→`Array[ItemType]`, local `$ref`→the referenced class name in the same family, `format: date-time`/`date`→`String`. When a schema is ambiguous, the generator SHALL fall back to `untyped` rather than fail.

#### Scenario: Primitive and array mapping
- **WHEN** a property has `type: array` with `items: {type: string}`
- **THEN** the RBS type SHALL be `Array[String]`

#### Scenario: Local ref resolution
- **WHEN** a property is `{$ref: "#/components/schemas/Address"}`
- **THEN** the type SHALL resolve to `Address` within the same family namespace

#### Scenario: date-time stays a string
- **WHEN** a property has `format: date-time`
- **THEN** the generated type SHALL be `String` (conversion to `Time` is left to the resource layer)

#### Scenario: Cross-file ref is unsupported
- **WHEN** a `$ref` points outside the current spec document
- **THEN** the generator SHALL emit `untyped` with a comment and a warning, never raising

### Requirement: Nullable and optional properties produce nullable RBS types and nil defaults
A property marked `nullable: true`, or any property absent from the schema's `required` list, SHALL be emitted with an RBS type suffixed `?` and SHALL accept `nil`. Properties listed in `required: [...]` SHALL be typed as non-nullable in RBS.

#### Scenario: Optional property
- **WHEN** a property `email` is not in `required` (or is `nullable: true`)
- **THEN** its RBS type SHALL be `String?` and the value object SHALL accept `nil` for it

#### Scenario: Required property
- **WHEN** a property `name` is listed in `required`
- **THEN** its RBS type SHALL be non-nullable (`String`)

### Requirement: oneOf and allOf are mapped conservatively
`oneOf` between primitive types SHALL be emitted as an RBS union (e.g., `Integer | String`). `oneOf`/`anyOf` between object types, lacking a reliable discriminator, SHALL be emitted as `untyped` with an explanatory comment. `allOf` SHALL be a shallow merge of the member schemas' properties.

#### Scenario: oneOf of primitives
- **WHEN** a property has `oneOf: [{type: integer}, {type: string}]`
- **THEN** the RBS type SHALL be `Integer | String`

#### Scenario: oneOf of objects
- **WHEN** a property has `oneOf` between two object schemas
- **THEN** the type SHALL be `untyped` with a comment such as `# oneOf: A | B`, and the generator SHALL NOT raise

#### Scenario: allOf composition
- **WHEN** a schema uses `allOf` to compose two object members
- **THEN** the generated value object SHALL include the union of both members' properties (last writer wins on collision, with a warning)

### Requirement: Every generated file carries a frozen-string header and AUTO-GENERATED banner
Every generated `.rb` file SHALL begin with `# frozen_string_literal: true` on the first line, followed by a banner `# AUTO-GENERATED — do not edit`, the source spec path, and a `sha256` hash of the source spec. Every generated `.rbs` file SHALL carry an equivalent comment banner.

#### Scenario: Ruby header
- **WHEN** any `.rb` file is generated
- **THEN** its first line SHALL be `# frozen_string_literal: true` and the following comment lines SHALL include `# AUTO-GENERATED — do not edit`, `# Source: openapi/<spec>.yaml`, and `# Hash: sha256:<hash>`

#### Scenario: RBS header
- **WHEN** any `.rbs` file is generated
- **THEN** it SHALL carry an equivalent `# AUTO-GENERATED — do not edit` comment banner with source and hash

### Requirement: Namespaces are named after spec families deterministically
The generator SHALL derive the Ruby module name from the spec filename by converting kebab-case to PascalCase and preserving the version suffix (`v1`→`V1`), and the directory/file path by converting to snake_case. Portuguese spec names SHALL NOT be translated.

#### Scenario: Namespace derivation
- **WHEN** the spec file is `service-invoice-rtc-v1.yaml`
- **THEN** the module SHALL be `Nfe::Generated::ServiceInvoiceRtcV1` and the directory SHALL be `lib/nfe/generated/service_invoice_rtc_v1/`

#### Scenario: Version suffix is preserved
- **WHEN** both `consulta-cnpj.yaml` and `consulta-cnpj-v3.yaml` are present
- **THEN** they SHALL produce distinct namespaces `ConsultaCnpj` and `ConsultaCnpjV3` so multi-version families coexist without collision

### Requirement: Generator output is deterministic
Running the generator twice over the same specs SHALL produce byte-identical output. Schemas and properties SHALL be ordered stably (by name), and no variable timestamp SHALL appear inside any file content that the sync guard compares.

#### Scenario: Idempotent generation
- **WHEN** the generator is run twice in a row against unchanged specs
- **THEN** the second run SHALL produce files byte-identical to the first

#### Scenario: Marker timestamp isolated from the diff
- **WHEN** `lib/nfe/generated/generated_marker.rb` records a `generated_at` timestamp
- **THEN** that timestamp SHALL be excluded or normalised in the sync-guard comparison so it never causes false drift

### Requirement: A sync guard fails CI when generated output drifts from specs
The SDK SHALL provide `rake generate:check` (wrapping `ruby scripts/generate.rb --check`) that regenerates output in memory, diffs it against the committed files in both `lib/nfe/generated/` and `sig/nfe/generated/`, and exits non-zero if any file would be added, removed, or changed. A CI job `openapi-sync` SHALL run this check.

#### Scenario: In sync
- **WHEN** `rake generate:check` runs and the committed generated files match the specs
- **THEN** it SHALL print an in-sync message and exit zero

#### Scenario: Spec changed without regenerating
- **WHEN** an `openapi/*.yaml` spec is modified but `lib/nfe/generated/` (or `sig/nfe/generated/`) is not regenerated, and `rake generate:check` runs in CI
- **THEN** the check SHALL list the added/removed/changed files and exit non-zero, failing the PR

#### Scenario: Both output trees are covered
- **WHEN** only an `.rbs` signature drifts from the spec while the `.rb` is in sync
- **THEN** the check SHALL still detect the drift and exit non-zero

### Requirement: Specs are validated before code is emitted
The spec loader SHALL parse each spec, verify it is a YAML/JSON document declaring an OpenAPI/Swagger version, and treat `components.schemas` as a map. A broken spec SHALL raise loudly during generation rather than silently emitting corrupt code. A spec without `components.schemas` SHALL produce no namespace.

#### Scenario: Broken spec fails fast
- **WHEN** a spec file is not parseable as a YAML/JSON document
- **THEN** the generator SHALL raise with a message naming the offending file, and SHALL NOT write partial output

#### Scenario: Spec without schemas produces nothing
- **WHEN** a spec has no `components.schemas` (e.g., `nf-servico-v1.yaml` deriving its type from `operations[...]`, or `cpf-api.yaml`)
- **THEN** the generator SHALL skip it without error, and the missing DTOs SHALL be hand-written by the resource changes (not under `lib/nfe/generated/`)

### Requirement: Specs are synced from nfeio-docs via a documented manual mechanism
The SDK SHALL provide `rake openapi:sync` that copies the spec set from nfeio-docs (`docs/static/api/*.{yaml,json}`, path configurable) into `openapi/`, normalising JSON to YAML where applicable, without committing or regenerating. `CONTRIBUTING.md` SHALL document the full flow: sync → review diff → `rake generate` → review generated output → commit specs and generated files together. nfeio-docs SHALL be documented as the source of truth.

#### Scenario: Syncing specs
- **WHEN** `rake openapi:sync` runs with nfeio-docs available
- **THEN** it SHALL update `openapi/*.yaml` from the docs source and report the file diff, without committing or triggering generation

#### Scenario: Documented sync workflow
- **WHEN** a contributor needs to refresh the API contract
- **THEN** `CONTRIBUTING.md` SHALL instruct them to run `rake openapi:sync`, review the diff, run `rake generate`, review `lib/nfe/generated/` and `sig/nfe/generated/`, and commit all three together

### Requirement: Generated directories are excluded from strict lint and type checks
The generated trees `lib/nfe/generated/**` and `sig/nfe/generated/**` SHALL be excluded from strict RuboCop and Steep targets (generated code tolerates broad shapes), while the generated RBS signatures SHALL still be loaded so the hand-written surface type-checks against them. Generated paths SHALL be marked `linguist-generated=true` in `.gitattributes`.

#### Scenario: RuboCop skips generated code
- **WHEN** RuboCop runs across the repository
- **THEN** files under `lib/nfe/generated/` SHALL be excluded from offenses while the hand-written surface remains strictly linted

#### Scenario: Generated RBS still informs Steep
- **WHEN** Steep type-checks the hand-written resource layer that consumes a generated value object
- **THEN** the signatures under `sig/nfe/generated/` SHALL be loaded so the generated types are known, even though `lib/nfe/generated/` itself is not strictly checked

#### Scenario: Generated diffs hidden on GitHub
- **WHEN** a PR regenerates `lib/nfe/generated/**` or `sig/nfe/generated/**`
- **THEN** `.gitattributes` SHALL mark those paths `linguist-generated=true` so the diffs are collapsed by default
