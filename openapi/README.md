# OpenAPI specs

These OpenAPI documents are the **source of truth** for the generated value
objects under `lib/nfe/generated/` (and their signatures under
`sig/nfe/generated/`). They are **copied manually** from the official
documentation repository after review — never hand-edited here.

- **Source:** `nfeio-docs` → `docs/static/api/` (https://nfe.io).
- **Snapshot:** 2026-07-09 (verificado contra `nfe/docs` `main`; specs idênticos byte a byte).
- **Sync:** `rake openapi:sync` copies the spec set from `nfeio-docs`
  (path configurable via `NFEIO_DOCS_PATH`) into this directory and reports the
  diff. It does **not** run `rake generate` or commit — that is a deliberate
  human review step. See `CONTRIBUTING.md`.

## How specs map to generated code

Each spec produces one generated family namespace `Nfe::Generated::<Family>`
(e.g. `service-invoice-rtc-v1.yaml` → `Nfe::Generated::ServiceInvoiceRtcV1`),
with one `Data.define` value object per schema under `components.schemas`.

`.json` specs (e.g. `contribuintes-v2.json`, `consumer-invoice.json`) are parsed
directly — JSON is valid YAML, so the loader (Psych) reads both.

## Specs without `components.schemas`

Some specs declare their request/response shapes inline under `operations[...]`
rather than in `components.schemas`. Those produce **no** generated namespace;
the DTOs they would need are hand-written in the resource changes instead. The
generator logs each skipped spec. (Known example: `cpf-api.yaml` — the
definitive list is reported by `rake generate`.)

A spec can also be only **partially** componentized: `nf-servico-v1.yaml`
declares `ErrorsResource` in `components.schemas` (so it generates the
errors-only `nf_servico_v1` namespace), while its success responses remain
inline — the `Nfe::ServiceInvoice` DTO stays hand-written, pinned to the spec
by an alignment test.
