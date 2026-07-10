# openapi-pipeline — Delta (expand-service-invoice-dto)

> Contexto: a atualização de `openapi/nf-servico-v1.yaml` (absorvida por esta
> change) adiciona `components.schemas.ErrorsResource`, então esse spec deixa
> de ser um exemplo válido de "spec sem schemas". O comportamento do gerador
> não muda — apenas o exemplo do cenário é corrigido (e o namespace
> `nf_servico_v1` passa a existir, contendo somente o modelo de erros).

## MODIFIED Requirements

### Requirement: Specs are validated before code is emitted
The spec loader SHALL parse each spec, verify it is a YAML/JSON document declaring an OpenAPI/Swagger version, and treat `components.schemas` as a map. A broken spec SHALL raise loudly during generation rather than silently emitting corrupt code. A spec without `components.schemas` SHALL produce no namespace. _(Behavior unchanged — this delta only refreshes the stale example in the scenario below; `nf-servico-v1.yaml` now carries `components.schemas.ErrorsResource` and generates an errors-only namespace, while its success responses remain inline and their DTOs hand-written.)_

#### Scenario: Spec without schemas produces nothing
- **WHEN** a spec has no `components.schemas` (e.g., `cpf-api.yaml` deriving its type from `operations[...]`)
- **THEN** the generator SHALL skip it without error, and the missing DTOs SHALL be hand-written by the resource changes (not under `lib/nfe/generated/`)
