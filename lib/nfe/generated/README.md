# Generated value objects — DO NOT EDIT

Every `.rb` in this directory (and every `.rbs` under `sig/nfe/generated/`) is
**auto-generated** from the OpenAPI specs in `openapi/` by `scripts/generate.rb`.
Each file carries an `# AUTO-GENERATED — do not edit` banner with its source spec
and a SHA-256 of that spec.

## Regenerating

```sh
rake generate          # rewrite lib/nfe/generated/** and sig/nfe/generated/**
rake generate:check    # CI gate: fails if the tree drifts from the specs
rake openapi:sync      # refresh openapi/*.yaml from nfeio-docs (NFEIO_DOCS_PATH)
```

Hand edits here will be **overwritten** on the next `rake generate` and will fail
`rake generate:check` in CI. To change a type, change the spec in `openapi/`
(synced from `nfeio-docs`, the source of truth) and regenerate. See
`CONTRIBUTING.md` for the full sync → review → generate → commit flow.

## Layout

- One `Nfe::Generated::<Family>` module per spec (e.g. `ServiceInvoiceRtcV1`).
- One immutable `Data.define` value object per `components.schemas` entry, each
  with a `from_api(payload)` class method (camelCase → snake_case, drops unknown
  keys, recurses into nested refs).
- `lib/nfe/generated.rb` is the `require_relative` loader; `generated_marker.rb`
  records the per-spec hashes.
