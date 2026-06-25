# add-lookup-resources

## Why

Os recursos de **lookup, consulta (query) e dados auxiliares** completam a superfície de 17 acessores do `Nfe::Client` e fecham a paridade-plus com os SDKs Node e PHP. Eles têm um perfil distinto dos recursos de invoice (de `add-invoice-resources`) e de entidade (companies/people/webhooks):

- **Read-only na maior parte**: devolvem dados normalizados (endereço por CEP, situação cadastral de CNPJ/CPF, eventos de NF-e, etc.). Nunca retornam o contrato 202 — respostas são sempre síncronas.
- **Multi-host agressivo**: esta change é o **principal exercitador do host map** definido em `add-client-core`. Seis das oito famílias vivem em hosts dedicados, fora do `https://api.nfe.io` padrão. Se o host map estiver errado, ~6 recursos retornam 404 ou batem no host errado.
- **`tax_calculation` é write-style** (POST com payload denso item-a-item) mas read-only no efeito — é um motor de cálculo, não persiste documento fiscal.
- **`state_taxes` é o único CRUD completo** desta change (list/create/retrieve/update/delete de Inscrições Estaduais por empresa).

Esta change implementa os 8 recursos como classes Ruby idiomáticas (`Data.define` para value objects imutáveis, keyword args, snake_case, `raise` de erros tipados), reutilizando `Nfe::Resources::AbstractResource`, `Nfe::IdValidator`, `Nfe::ListResponse` e o host map de `Nfe::Configuration` — todos entregues por **add-client-core** (dependência).

## What Changes (high-level)

### Recursos implementados (8)

| Recurso (acessor snake_case) | Família / host (via Configuration) | Operações |
|---|---|---|
| `addresses` | `addresses` → `https://address.api.nfe.io/v2` (o `/v2` é parte da base URL) | `lookup_by_postal_code`, `search`, `lookup_by_term` |
| `legal_entity_lookup` | `legal-entity` → `https://legalentity.api.nfe.io` | `get_basic_info`, `get_state_tax_info`, `get_state_tax_for_invoice`, `get_suggested_state_tax_for_invoice` |
| `natural_person_lookup` | `natural-person` → `https://naturalperson.api.nfe.io` | `get_status` |
| `product_invoice_query` | `nfe-query` → `https://nfe.api.nfe.io` (paths `v2`) | `retrieve`, `download_pdf`, `download_xml`, `list_events` |
| `consumer_invoice_query` | `nfe-query` → `https://nfe.api.nfe.io` (paths `v1` + `/coupon/`) | `retrieve`, `download_xml` |
| `tax_calculation` | `cte` → `https://api.nfse.io` | `calculate` |
| `tax_codes` | `cte` → `https://api.nfse.io` | `list_operation_codes`, `list_acquisition_purposes`, `list_issuer_tax_profiles`, `list_recipient_tax_profiles` |
| `state_taxes` | `cte` → `https://api.nfse.io` (paths `v2`) | `list`, `create`, `retrieve`, `update`, `delete` |

### Adicionado (suporte)

- **Extensão de `Nfe::IdValidator`** (a classe base vive em `add-client-core`): adiciona `cep`, `state` (UF de 2 letras + `EX` + `NA`), `cnpj` e `cpf`. Cada validador aceita entrada formatada (com pontos/hífens), normaliza para dígitos puros (ou UF maiúscula) e retorna o valor normalizado; `access_key` (44 dígitos) já existe em `add-client-core` e é reusado aqui.
- **`Nfe::DateNormalizer`** — `to_iso_date(input)` converte `String` (ISO `YYYY-MM-DD`) **ou** `Date`/`Time`/`DateTime` para uma string `YYYY-MM-DD`. Usado por `natural_person_lookup.get_status`. (Node aceita `string | Date`; em Ruby aceitamos `String` e os tipos de data da stdlib `date`/`time`.)
- **Value objects gerados/hand-written** em `lib/nfe/generated/` (quando o gerador OpenAPI cobre o schema) ou em `lib/nfe/resources/dto/<family>/` (hand-written quando o gen for esparso): `AddressLookupResponse`, `LegalEntityBasicInfoResponse`, `LegalEntityStateTaxResponse`, `LegalEntityStateTaxForInvoiceResponse`, `NaturalPersonStatusResponse`, `CalculateResponse`, `TaxCodePaginatedResponse`, `ProductInvoiceDetails`, `ProductInvoiceEventsResponse`, `TaxCoupon` (e sub-objetos), `NfeStateTax`. Todos `Data.define` imutáveis.

### Não inclui (fora de escopo desta release)

- **Validação de dígito verificador (Module-11) de CNPJ/CPF** — Node tem helpers; o servidor já valida. A validação local é fail-fast contra typo (comprimento/forma), não substitui a validação fiscal. Replicar Module-11 é custo sem ganho real.
- **CNPJ alfanumérico (IN RFB 2.229/2024, vigente jul/2026)** — vive nas APIs **v3** (`consulta-cnpj-v3`). As famílias v1/v2 desta change continuam numéricas. `IdValidator::cnpj` v1 valida 14 dígitos numéricos; suporte alfanumérico (não coagir para Integer) é uma evolução futura sobre endpoints v3, registrada como risco em `design.md`.
- **Builder fluente para o payload de `tax_calculation.calculate`** — aceitamos `Hash`; quem quer type-safety constrói o value object gerado `Nfe::Generated::CalculoImpostosV1::CalculateRequest` e passa via `to_h`.
- **Parser de OData `$filter`** em `addresses.search` — o filtro é repassado opaco para a query string; o caller é responsável por montá-lo.
- **Camada de cache** das respostas de lookup — o caller decide.

## Capabilities

### New Capabilities
- `lookup-resources`: os 8 recursos de lookup/query/state-tax + `Nfe::DateNormalizer` + a extensão dos validadores de `IdValidator` (cep/state/cnpj/cpf) + os value objects de resposta.

### Modified Capabilities
- (nenhuma) — o host map e os blocos compartilhados (`Nfe::Resources::AbstractResource`, `IdValidator` base, `ListResponse`, lazy accessors) pertencem a **add-client-core**; esta change apenas os consome.

## Impact

- **Affected code**: `lib/nfe/resources/{addresses,legal_entity_lookup,natural_person_lookup,product_invoice_query,consumer_invoice_query,tax_calculation,tax_codes,state_taxes}.rb` (cada um herda de `Nfe::Resources::AbstractResource`), `lib/nfe/date_normalizer.rb`, `lib/nfe/id_validator.rb` (extensão cep/state/cnpj/cpf), value objects sob `lib/nfe/generated/**` ou `lib/nfe/resources/dto/**`.
- **Signatures**: `sig/nfe/resources/*.rbs` para cada recurso, `sig/nfe/date_normalizer.rbs`, e `sig/nfe/id_validator.rbs` (assinaturas dos novos validadores). Type-check com Steep, lint com RuboCop.
- **Tests**: `spec/nfe/resources/*_spec.rb` por recurso, mais `spec/nfe/date_normalizer_spec.rb` e cobertura dos novos validadores em `spec/nfe/id_validator_spec.rb`. Cada spec de recurso **assertiona o host de saída** (`https://address.api.nfe.io/v2`, `https://legalentity.api.nfe.io`, `https://naturalperson.api.nfe.io`, `https://nfe.api.nfe.io`, `https://api.nfse.io`) via transporte mockado. Cobertura >= 80% via SimpleCov.
- **Spec impact**: adiciona a capability `lookup-resources`; não modifica outras capabilities.
- **Dependencies**: **depende de add-client-core** (host map em `Nfe::Configuration`, `Nfe::Resources::AbstractResource`, `Nfe::IdValidator` base com `access_key`, `Nfe::ListResponse`, accessores lazy no `Nfe::Client`) e transitivamente de **add-ruby-foundation** (gem, namespace, RBS/Steep/RuboCop/RSpec, `frozen_string_literal`). Pode ser implementada em paralelo com **add-invoice-resources** — não há sobreposição de arquivos (ambas estendem `IdValidator`, mas em métodos distintos: invoice usa `company_id`/`invoice_id`/`access_key`/`state_tax_id`/`event_key`; lookup adiciona `cep`/`state`/`cnpj`/`cpf`).
- **Cross-reference**: `consumer_invoice_query` é a **consulta de NFC-e por chave de acesso** (read-only, sem escopo de empresa, host `nfe.api.nfe.io`). É distinto de `consumer_invoices` (emissão de NFC-e, escopada por empresa, host `api.nfse.io`), que pertence a **add-invoice-resources**. Os dois recursos coexistem no `Nfe::Client` e não devem ser confundidos.
- **Risks**:
  - Hosts dedicados (`legalentity.api.nfe.io`, `naturalperson.api.nfe.io`) podem mudar; o `Nfe::Configuration` centraliza o mapa (único ponto a ajustar) e os specs travam o host esperado por recurso. Os specs do PHP listavam por engano `api-legalentity.nfe.io`/`api-naturalperson.nfe.io` — o host canônico (confirmado no Node SDK) é `*.api.nfe.io`. Esta change usa o canônico.
  - Rate limits / cobrança por chamada agressivos em lookup de CNPJ/CPF (cobrado pela NFE.io). A política de retry de `add-client-core` honra `Retry-After`; o caller deve estar ciente do custo.
  - O payload de `tax_calculation.calculate` é denso; risco de divergência entre o shape aceito pelo motor e o que o gerador produz. Mitigado por aceitar `Hash` opaco (SDK não força shape).
  - `consumer_invoice_query` usa paths **v1** + `/coupon/` enquanto `product_invoice_query` usa **v2** — mesmo host (`nfe.api.nfe.io`), versões diferentes. Risco de troca de versão; coberto por specs explícitos de path.
