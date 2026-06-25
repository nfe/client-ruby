# add-openapi-pipeline

## Why

A NFE.io é a **fonte da verdade** para o comportamento da API e publica os contratos como specs OpenAPI versionados em `nfeio-docs` (`docs/static/api/*.yaml`). Os SDKs Node (via `openapi-typescript`) e PHP (via codegen custom em `scripts/generate.php`) já provaram o conceito: **gerar tipos a partir dos specs, não escrever DTOs à mão**. Replicar dezenas de schemas manualmente em Ruby seria trabalho repetido e fonte garantida de divergência silenciosa quando a API evolui (RTC, CNPJ alfanumérico v3, Contribuintes v2, etc.).

Esta change estabelece a pipeline de geração de código do SDK Ruby v1. Ela depende de `add-ruby-foundation` (que fixa gem `nfe-io` 1.0.0, namespace `Nfe`, piso Ruby 3.2, zero dependências de runtime, RBS/Steep/RuboCop/RSpec e a CI matrix 3.2/3.3/3.4). A pipeline produz a matéria-prima — value objects `Data.define` imutáveis e suas assinaturas `.rbs` — que os recursos hand-written (`add-invoice-resources` e changes irmãs) consomem.

A escolha é deliberada e espelha Node e PHP: **gerar tipos, não serviços**. Os recursos (`Nfe::Client` + accessors lazy, polling de 202, paginadores, helpers de webhook) são hand-written para garantir ergonomia Stripe-like. O codegen entrega apenas os DTOs tipados.

Restrição central herdada de `add-ruby-foundation`: **zero dependências de runtime**. O código gerado é Ruby puro de stdlib (`Data.define`); a geração em si é uma preocupação de **dev/build-time** e pode usar dependências dev-only confinadas a um grupo do Gemfile que nunca entra no gem publicado.

## What Changes

- **`scripts/generate.rb`** — script Ruby (não bash, não Java, não Node) que lê `openapi/*.yaml` e emite código em `lib/nfe/generated/` mais assinaturas em `sig/nfe/generated/`. Roda via `rake generate`.
- **Inventário de specs sincronizado do nfeio-docs** em `openapi/` deste repo — o mesmo conjunto de famílias que Node/PHP usam (NFS-e, NF-e, NFC-e, consultas, distribuição, CNPJ, CPF, endereço, cálculo de impostos, RTC, Contribuintes v2). Specs são versionados no repo; não há fetch automático em build.
- **Dev deps build-time** confinadas ao grupo `:codegen` do Gemfile (nunca em `add_dependency` do `.gemspec`):
  - parser de YAML maduro — preferência por `psych` (já é stdlib em Ruby 3.2+ via `require "psych"`), eliminando dependência externa quando possível; fallback documentado para uma gem dev-only se um spec exigir features de YAML que o Psych não cobre.
  - `prism` ou template-string com normalização determinística para emissão de Ruby legível (decisão registrada em design.md).
- **Layout de saída**:
  ```
  lib/nfe/generated/
    nf_servico_v1/
      <schema_name>.rb        # 1 Data.define por arquivo
    nf_produto_v2/
    nf_consumidor_v2/
    consulta_cte_v2/
    ...                       # 1 módulo Ruby por família de spec
    generated_marker.rb       # constante com timestamp + hash dos specs de origem
  sig/nfe/generated/
    nf_servico_v1/
      <schema_name>.rbs       # assinatura RBS espelhando cada Data.define
    ...
  ```
- **Namespaces nomeados pelas famílias de spec** (PascalCase a partir do filename kebab-case + sufixo de versão): `NfServicoV1`, `NfProdutoV2`, `NfConsumidorV2`, `ConsultaCteV2`, `ConsultaDfeDistribuicaoV2`, `CalculoImpostosV1`, `ConsultaCnpjV3`, `ServiceInvoiceRtcV1`, `ProductInvoiceRtcV1`, etc. Mapeamento mecânico e determinístico, sem tradução pt→en.
- **Banner anti-edição**: todo arquivo gerado (`.rb` e `.rbs`) começa com `# frozen_string_literal: true` seguido de `# AUTO-GENERATED — do not edit` + spec de origem + hash SHA-256.
- **Mapeamento de schema → Ruby idiomático**: `object` → `Data.define` imutável com keyword args; `enum` → módulo de constantes congeladas (`module X; A = "a"; ALL = [A].freeze; end`); `$ref` local → referência de classe na mesma família; `nullable`/opcional → keyword arg com default `nil`; `oneOf`/`allOf` mapeados conservadoramente (union de primitivos quando expressável, senão `Object`/`untyped` com comentário).
- **Hidratação `from_api` (GAP#7)**: cada `Data.define` gerado recebe um método de classe `from_api(payload)` que mapeia chaves camelCase→membros snake_case, descarta chaves desconhecidas e recursa em atributos `$ref` (objeto → `from_api` do DTO referenciado; array de `$ref` → `map` elemento a elemento). É o único método gerado no value object (modelo segue anêmico). O `.rbs` correspondente declara `def self.from_api`. O call site (`klass.from_api(payload)`) vive na camada hand-written de recursos, mas o produtor é esta pipeline.
- **Validação de spec**: o `SpecLoader` valida o YAML (parse OK, versão OpenAPI presente, `components.schemas` é mapa) e falha alto em spec quebrado em vez de emitir código corrompido.
- **Saída determinística**: ordenação estável de schemas e propriedades, banner sem timestamp variável dentro do corpo comparado, de modo que regenerar duas vezes produz bytes idênticos (pré-requisito para o guard de CI).
- **Rake tasks**: `rake generate` (escreve `lib/nfe/generated/` + `sig/nfe/generated/`) e `rake generate:check` (gera em memória/tmp, faz diff contra o checked-in, sai com código não-zero se houver drift).
- **Guard de CI "out-of-sync"**: job que roda `rake generate:check` e falha o PR se `openapi/*.yaml` mudou sem regenerar a saída.
- **Mecanismo de sync documentado**: `rake openapi:sync` (ou script equivalente) que copia/atualiza os YAMLs de `nfeio-docs` (`docs/static/api/`) para `openapi/` deste repo, mais a seção em `CONTRIBUTING.md` explicando o fluxo manual (revisão antes do commit).
- **RuboCop/Steep ignoram `lib/nfe/generated/` e `sig/nfe/generated/`** para análise estrita (gerado tolera shapes amplos), mantendo o rigor de tipo de `add-ruby-foundation` na superfície hand-written.
- **NÃO gera** clients, recursos, factories, polling, paginação ou qualquer surface acima de DTOs/enums — esses são hand-written nas changes de recursos.

## Capabilities

### New Capabilities
- `openapi-pipeline`: contrato de geração de value objects `Data.define` + enums + assinaturas RBS a partir dos specs OpenAPI sincronizados do nfeio-docs; layout `lib/nfe/generated/` + `sig/nfe/generated/`; política de não-edição manual; saída determinística; rake tasks `generate`/`generate:check`; guard de sincronia em CI; mecanismo de sync-from-docs documentado.

### Modified Capabilities
- (nenhuma) — depende de `add-ruby-foundation`, mas não modifica sua spec; apenas a consome (toolchain RBS/Steep/RuboCop/CI matrix).

## Impact

- **Affected code**: `scripts/generate.rb` + `scripts/generator/*.rb` (loader, name_mapper, type_mapper, schema_compiler, enum_compiler, rbs_emitter, ruby_emitter, check_mode); `lib/nfe/generated/**` (gerado); `sig/nfe/generated/**` (gerado); `Rakefile` (tasks `generate`, `generate:check`, `openapi:sync`); `Gemfile` (grupo dev-only `:codegen`); `.github/workflows/ci.yml` (job `openapi-sync`); `openapi/*.yaml` (specs sincronizados); `CONTRIBUTING.md` (fluxo de sync); `.rubocop.yml` e `Steepfile` (exclusões de `lib/nfe/generated/`).
- **Build-time deps**: confinadas ao grupo `:codegen` do Gemfile; preferência por stdlib (`psych`, `digest`, `fileutils`). **Runtime deps: zero** — `lib/nfe/generated/**` é Ruby puro de stdlib (`Data.define`), sem `require` de gem externa.
- **Source of truth**: `nfeio-docs` (`docs/static/api/*.yaml`). `openapi/*.yaml` neste repo é uma cópia versionada e revisada (sync manual via `rake openapi:sync`), não um download automático em build.
- **Downstream**: `add-invoice-resources` e demais changes de recursos importam tipos de `Nfe::Generated::*` quando precisam de DTOs tipados; hidratam os `Data.define` a partir das respostas HTTP.
- **Spec impact**: adiciona a capability `openapi-pipeline`; não modifica `ruby-foundation`.
- **Dependencies**: depende de `add-ruby-foundation` (toolchain, namespace, piso Ruby, regra zero-dep, RBS/Steep/RuboCop/CI).
- **Risks**:
  - Codegen custom é manutenção própria. Mitigação: escopo mínimo (objects, enums, refs, nullable, oneOf/allOf simples); quando em dúvida, gerar tipo amplo em vez de quebrar.
  - Specs OpenAPI da NFE.io são imperfeitos (`nullable` ausente, `oneOf` sem discriminator, alguns sem `components.schemas` — ex.: `nf-servico-v1` deriva o ServiceInvoice de `operations[...]`, e `cpf-api` não tem schemas). O gerador deve ser tolerante e os DTOs faltantes ficam hand-written nas changes de recursos.
  - Drift entre `lib/nfe/generated/` e `sig/nfe/generated/` — mitigado por gerar ambos no mesmo passo e cobrir os dois no `generate:check`.
