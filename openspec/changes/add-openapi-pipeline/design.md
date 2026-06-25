# Design — add-openapi-pipeline

## Context

A NFE.io publica os contratos da API como specs OpenAPI versionados em `nfeio-docs` (`docs/static/api/*.yaml`). Esse é o **source-of-truth** para o comportamento da API. Os SDKs irmãos já resolveram a geração de tipos a partir desses specs:

- **Node**: `scripts/generate-types.ts` usa `openapi-typescript` (gera só types, não services) e escreve em `src/generated/`, um arquivo por spec, com banner anti-edição e namespace derivado do filename (`nf-servico-v1` → `NfServico`).
- **PHP**: `scripts/generate.php` + `scripts/Generator/*` é um codegen custom (deps dev-only `symfony/yaml` + `nikic/php-parser`) que emite `final readonly class` em `src/Generated/<NamespacePorSpec>/`, com `composer generate` / `generate:check` e job de CI `openapi-sync`. Gerou **415 arquivos em 10 namespaces** na execução real.

Esta change traz o mesmo conceito para Ruby, adaptado a duas restrições herdadas de `add-ruby-foundation`:

1. **Zero dependências de runtime** — o gem publicado (`nfe-io` 1.0.0) só pode depender da stdlib (`net/http`, `json`, `openssl`, `uri`, `securerandom`, `stringio`, `time`, `base64`). Logo o código gerado tem de ser Ruby puro de stdlib (`Data.define`), e as deps de geração ficam confinadas a um grupo dev-only do Gemfile.
2. **Rigor de tipo paralelo a Node (.d.ts) e PHP (PHPStan L8)** — o SDK Ruby entrega assinaturas RBS e checa com Steep no CI. Portanto o gerador precisa emitir **`.rb` E `.rbs` no mesmo passo**, não só os value objects.

A decisão estratégica é a mesma de Node/PHP: **gerar tipos, não serviços**. A superfície hand-written (`Nfe::Client` Stripe-style com accessors lazy snake_case, polling de 202, paginadores, helpers de webhook, hidratação) é escrita à mão nas changes de recursos (`add-invoice-resources` e irmãs). O codegen entrega apenas os DTOs/enums tipados como matéria-prima.

Caveat de recon importante: alguns specs são "esparsos" — `nf-servico-v1` deriva o `ServiceInvoice` de `operations[...]` (0 component schemas) e `cpf-api` não tem `components.schemas`. Esses não produzem namespace gerado; os DTOs faltantes ficam hand-written nas changes de recursos (mesmo padrão que o PHP adotou para `cpf-api-v3`).

## Goals / Non-Goals

**Goals**
- `scripts/generate.rb` ergonômico, idempotente, rápido, rodável com `ruby scripts/generate.rb` (sem Java, sem Node).
- Saída em `lib/nfe/generated/<module_path>/<schema>.rb` (value objects `Data.define` imutáveis) E `sig/nfe/generated/<module_path>/<schema>.rbs` (assinaturas espelhadas), 1 schema por arquivo.
- Banner `# AUTO-GENERATED — do not edit` + spec de origem + hash SHA-256 em todo arquivo gerado; primeira linha sempre `# frozen_string_literal: true`.
- Suporte a: `object` schemas, `enum`, `$ref` locais, `nullable`, `oneOf`/`allOf` simples, formatos básicos (`string`, `integer`, `number`, `boolean`, `date-time`).
- Namespaces nomeados pelas famílias de spec, mecanicamente (`NfServicoV1`, `NfProdutoV2`, `ConsultaCteV2`, `CalculoImpostosV1`, `ServiceInvoiceRtcV1`, `ProductInvoiceRtcV1`, etc.).
- Saída **determinística** — regenerar duas vezes produz bytes idênticos (pré-requisito do guard de CI).
- `rake generate` / `rake generate:check`; job de CI `openapi-sync` que falha PRs com drift.
- Mecanismo de sync-from-docs documentado (`rake openapi:sync` + seção no CONTRIBUTING.md).
- Zero dep de runtime: deps de geração só no grupo `:codegen` do Gemfile.

**Non-Goals**
- Gerar clients, recursos, factories, polling, paginação ou HTTP — tudo hand-written nas changes de recursos.
- Gerar request/response builders mágicos.
- Suportar features avançadas de OpenAPI 3.1 (JSON Schema 2020-12 dialect completo).
- Fetch automático de specs da web — specs são versionados no repo após revisão manual.
- Watch mode de codegen.
- Resolver `$ref` cross-file — cada spec é self-contained.
- Conversão automática de `date-time` → `Time` no DTO (fica em helpers da camada de recursos).

## Decisions

### D1. Codegen custom em Ruby, não Java/Node
**Decisão**: `scripts/generate.rb` é Ruby puro, rodável com `ruby scripts/generate.rb`.

**Por quê**: o desenvolvedor que pega este SDK conhece Ruby. Exigir Node (como o gerador do Node SDK exige) ou Java (openapi-generator-cli) só para regenerar tipos é hostil e quebra o "closed loop" — Ruby gera Ruby. Espelha a decisão do PHP (PHP gera PHP).

**Alternativa rejeitada**: reaproveitar `openapi-typescript` + um transpiler. Acopla a toolchain Ruby a Node; descartado.

### D2. Parser YAML: `psych` (stdlib), não gem externa
**Decisão**: usar `psych` (`require "psych"`), que é stdlib em Ruby 3.2+, como parser primário.

**Por quê**: evita até a dependência dev-only de YAML que o PHP precisou (`symfony/yaml`). Psych é maduro, embarcado, suficiente para OpenAPI 3.x. Mantém o footprint de build mínimo.

**Por quê não uma gem (ex.: `oas_parser`, `openapi3_parser`)**: deps pesadas e barrocas; o escopo é pequeno (objects, enums, refs); custom dá controle total. Espelha a rejeição do PHP a `jane-php/open-api` e `openapi-generator-cli`.

**Risco**: alguns specs do docs vêm como `.json` (ex.: `consumer-invoice.json`, `contribuintes-v2.json`). Mitigação: normalizar JSON→YAML no `rake openapi:sync` OU o `SpecLoader` aceita ambos (`JSON.parse` para `.json`). Registrado em tasks §2.3.

### D3. Emissão de código: template determinístico, não AST pesado
**Decisão**: emitir `.rb` e `.rbs` via template-string com normalização determinística (indentação fixa, ordenação estável). Avaliar `prism` (parser/emitter oficial Ruby 3.3+, dev-only) como reforço de formatação, mas a saída-alvo (`Data.define` anêmico + `module` de enum) é simples o bastante para template controlado.

**Por quê**: o PHP precisou de `nikic/php-parser` porque emitir PHP com escapes/visibilidade/promotion à mão é frágil. O alvo Ruby aqui é muito mais simples — uma linha `Const = Data.define(:a, :b)` e constantes congeladas. Um template determinístico e bem testado é menos dependência e mais legível. A formatação consistente é garantida por testes de snapshot + idempotência.

**Alternativa rejeitada**: gerar via `RuboCop -a` pós-emissão. Acopla a saída ao RuboCop e introduz não-determinismo entre versões; descartado.

### D4. Saída dupla `.rb` + `.rbs` no mesmo passo
**Decisão**: cada schema gera DOIS arquivos — `lib/nfe/generated/<family>/<schema>.rb` (o `Data.define`) e `sig/nfe/generated/<family>/<schema>.rbs` (a assinatura). Ambos saem do mesmo modelo interno (`SchemaCompiler`) num único `generate`.

**Por quê**:
- `add-ruby-foundation` exige RBS + Steep no CI; o tipo de um value object gerado precisa de assinatura RBS para a camada hand-written tipar contra ele.
- Gerar os dois do mesmo modelo elimina drift entre código e assinatura.
- O `generate:check` cobre os dois diretórios, então o CI pega divergência de qualquer um.

**Alternativa rejeitada**: gerar só `.rb` e deixar RBS para `rbs prototype rb`. O protótipo do `rbs` produz `untyped` em massa (perde a riqueza do spec); descartado.

### D5. Layout: módulo por família de spec, não por entidade
**Decisão**:
```
lib/nfe/generated/nf_servico_v1/<schema>.rb     -> Nfe::Generated::NfServicoV1::<Schema>
lib/nfe/generated/nf_produto_v2/<schema>.rb     -> Nfe::Generated::NfProdutoV2::<Schema>
```
em vez de achatar todos os schemas num único namespace.

**Por quê**: schemas com nomes iguais aparecem em specs diferentes (`Address`, `Borrower`, `Company`). Módulo por família evita colisão. O nome do módulo vem do filename do spec (kebab→PascalCase + versão): `service-invoice-rtc-v1.yaml` → `ServiceInvoiceRtcV1`; o diretório usa snake_case (`service_invoice_rtc_v1`). Espelha a decisão D4 do PHP.

### D6. `object` schema → `Data.define` imutável com keyword args
**Decisão**: cada schema `object` vira `Const = Data.define(:attr_a, :attr_b, ...)`. A hidratação (camada de recursos) constrói via keyword args.

```ruby
# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-servico-v1.yaml
# Hash: sha256:abcd...

module Nfe
  module Generated
    module NfServicoV1
      # borrower (original: Borrower)
      Borrower = Data.define(
        :name,                # String
        :federal_tax_number,  # Integer? (original: federalTaxNumber)
        :email,               # String?
      ) do
        # Hidrata a partir do payload da API: mapeia camelCase→snake_case,
        # descarta chaves desconhecidas, recursa em refs aninhados.
        def self.from_api(payload)
          return nil if payload.nil?
          new(
            name: payload["name"],
            federal_tax_number: payload["federalTaxNumber"],
            email: payload["email"],
          )
        end
      end
    end
  end
end
```

**Por quê**: decisão canônica do projeto — "immutable Data.define value objects". `Data.define` é frozen por construção, gera `==`/`hash`/`deconstruct` de graça, e é stdlib puro (zero dep). Modelos anêmicos: sem lógica de negócio — o único método gerado é `from_api`, a hidratação determinística do payload (camel→snake, drop de chaves desconhecidas, recursão em objetos/arrays `$ref` via o `from_api` do DTO referenciado). A camada hand-written de recursos chama `klass.from_api(payload)`; o produtor do método e do `.rbs` correspondente é esta pipeline (GAP#7).

**Alternativa rejeitada**: `Struct` mutável ou classe à mão com `attr_reader`. `Struct` é mutável (viola imutabilidade); classe à mão é verbosa. `Data.define` é o idioma Ruby 3.2+ correto.

### D7. `enum` → módulo de constantes congeladas
**Decisão**: schema com `enum: [...]` vira um `module` de constantes:
```ruby
module FlowStatus
  Issued       = "Issued"
  IssueFailed  = "IssueFailed"
  Cancelled    = "Cancelled"
  CancelFailed = "CancelFailed"
  ALL = [Issued, IssueFailed, Cancelled, CancelFailed].freeze
end
```

**Por quê**: Ruby não tem enum nativo como PHP 8.1. Um módulo de constantes congeladas é zero-dep, idiomático, e dá `ALL` para iteração/validação. A camada de recursos (ex.: `FlowStatus` terminal-state helper de `add-invoice-resources`) consome essas constantes.

**Alternativa rejeitada**: gem de enum (`ruby-enum`) — viola zero-dep. Símbolos soltos — perdem a lista canônica e o backing value.

### D8. `nullable`/opcional → keyword arg com default `nil` + tipo RBS `T?`
**Decisão**: campo `nullable: true` ou não listado em `required` → tipo RBS `T?` e, no `Data.define`, o atributo aceita `nil` (a hidratação passa keyword default `nil`). Campos em `required: [...]` são tratados como obrigatórios na assinatura RBS.

**Por quê**: nullability explícita; Steep pega quem esquecer. Fiel ao spec.

**Nota**: `Data.define` em si não impõe required/optional em runtime; o rigor vive na assinatura RBS + na hidratação. O DTO gerado é anêmico e permissivo por construção; a tipagem estática é a guarda.

### D9. `format: date-time` → `String`, não `Time`
**Decisão**: representar `date-time`/`date` como `String` no DTO gerado; a conversão para `Time` fica em helpers da camada de recursos.

**Por quê**: a API retorna ISO 8601 timezone-aware. Auto-converter no DTO acopla parsing à geração e perde o wire format. Espelha a decisão D9 do PHP (lá: `string`, não `DateTimeImmutable`). `time` é stdlib, então o helper de cima fica trivial sem dep.

### D10. `oneOf` simples → union RBS; complexo → `untyped`
**Decisão**: `oneOf` entre primitivos (`[integer, string]`) → union RBS `Integer | String` (o keyword arg Ruby aceita ambos naturalmente). `oneOf`/`anyOf` entre objetos, sem discriminator confiável → `untyped` com comentário `# oneOf: A | B`.

**Por quê**: os specs da NFE.io raramente trazem `discriminator` confiável. Conservador por design: em dúvida, `untyped` em vez de quebrar o gerador. Espelha D8 do PHP (`mixed` para `oneOf` complexo). `allOf` faz merge raso das propriedades (composição).

### D11. CI guard via `rake generate:check`
**Decisão**: `--check` gera em memória, compara com o checked-in em `lib/nfe/generated/` E `sig/nfe/generated/`, e sai com código não-zero se houver `added`/`removed`/`changed`. Job `openapi-sync` no CI roda isso.

**Por quê**: PR que toca `openapi/*.yaml` sem regenerar não passa — força sincronia. Espelha D10 do PHP. O determinismo (D12) é o que torna o diff confiável.

### D12. Saída determinística
**Decisão**: ordenar schemas e propriedades por nome; sem timestamp dentro do corpo comparado (o `generated_marker.rb` isola o `generated_at` e ele é normalizado/ignorado no check); ordenação de Hash explícita (não dependente de inserção do YAML).

**Por quê**: o guard de CI só é confiável se "gerar duas vezes" produzir bytes idênticos. Qualquer não-determinismo gera falsos positivos de drift.

### D13. Mapeamento de nome de spec → namespace
**Decisão**: kebab-case + sufixo de versão → PascalCase para o módulo, snake_case para o diretório/arquivo:
- `service-invoice-rtc-v1.yaml` → módulo `ServiceInvoiceRtcV1`, dir `service_invoice_rtc_v1`
- `consulta-cnpj-v3.yaml` → `ConsultaCnpjV3` / `consulta_cnpj_v3`
- `calculo-impostos-v1.yaml` → `CalculoImpostosV1` / `calculo_impostos_v1`

**Por quê**: mecânico, determinístico, sem ambiguidade. Português nos nomes de spec é OK — tradução pt→en perderia info (specs originais são em pt). Espelha D12 do PHP. **Divergência consciente vs Node**: o Node SDK remove o sufixo de versão (`nf-servico-v1` → `NfServico`); aqui PRESERVAMOS a versão (`NfServicoV1`) para conviver com famílias multi-versão (v1/v2/v3 do mesmo domínio coexistem — ex.: `consulta-cnpj` numérico e `consulta-cnpj-v3` alfanumérico).

### D14. Deps de geração isoladas em grupo dev-only do Gemfile
**Decisão**: tudo que a geração usa fica em `group :codegen do ... end` no Gemfile; `nfe-io.gemspec` não declara nenhum `add_dependency`. `bundle install --without codegen` produz ambiente de runtime limpo.

**Por quê**: a regra canônica é zero dep de runtime. A geração é build-time. Confinar ao grupo `:codegen` garante que o gem publicado não arrasta nada. Como o parser preferido é `psych` (stdlib), o grupo `:codegen` pode até ficar quase vazio.

### D15. Onde ficam DTOs não cobertos pelo gerador
**Decisão**: specs sem `components.schemas` (ex.: `nf-servico-v1` deriva de `operations[...]`, `cpf-api` sem schemas) não produzem namespace gerado. Os DTOs de response correspondentes ficam **hand-written** nas changes de recursos, em `lib/nfe/resources/dto/<family>/` (separado de `lib/nfe/generated/` para não conflitar com o guard de sincronia).

**Por quê**: o gerador lê `components.schemas`; o que não está lá não é gerável. Forçar geração a partir de `operations[...]` (como o Node faz para derivar tipos de operação) é fora de escopo desta pipeline (que gera só DTOs de schema). Espelha a nota do PHP sobre `cpf-api-v3`. Registrado em tasks §10.7.

### D16. Sync-from-docs é manual e revisado
**Decisão**: `rake openapi:sync` copia `nfeio-docs/static/api/*.{yaml,json}` para `openapi/`, mas NÃO faz commit nem regenera. O fluxo no CONTRIBUTING.md é: `sync` → revisar diff → `generate` → revisar `.rb`/`.rbs` → commit dos três juntos.

**Por quê**: specs imperfeitos não podem entrar no SDK sem revisão humana. Fetch automático em build introduziria specs "broken" silenciosamente. Espelha a escolha do PHP ("não há fetch automático — escolha consciente"). O source-of-truth é nfeio-docs; o Node SDK está atrás dos docs (RTC e v3 ainda não estão no spec dir dele), então o Ruby sincroniza direto da fonte.

### D17. Template RBS fixo para DTOs gerados + loader por `require_relative` explícito
**Decisão**: o `.rbs` de cada DTO segue um template fixo — `class <Const> < Data` com atributos tipados (reader por atributo), assinatura de construtor por keyword args, e a assinatura de `from_api`:
```rbs
# AUTO-GENERATED — do not edit
# Source: openapi/nf-servico-v1.yaml
# Hash: sha256:abcd...
module Nfe
  module Generated
    module NfServicoV1
      class Borrower < Data
        attr_reader name: String
        attr_reader federal_tax_number: Integer?
        attr_reader email: String?
        def self.new: (?name: String, ?federal_tax_number: Integer?, ?email: String?) -> instance
        def self.from_api: (Hash[String, untyped] payload) -> instance
      end
    end
  end
end
```
O carregamento da árvore gerada é por **`require_relative` explícito**: o gerador emite, junto com a árvore, um arquivo `lib/nfe/generated.rb` que faz `require_relative` de cada arquivo gerado em ordem estável (refs antes dos consumidores quando possível; `Data.define` tolera referência tardia pois `from_api` só resolve no call-time). Sem autoload mágico.

**Por quê**: o template RBS fixo garante que o `.rbs` espelha exatamente o `.rb` (mesmo modelo interno, D4), inclusive a assinatura de `from_api` (GAP#7), e mantém o output determinístico (D12). `require_relative` explícito é zero-dep, previsível, e amigável ao `generate:check` (a lista de requires é ela própria determinística e versionada); autoload (`Zeitwerk`/`autoload`) acoplaria carregamento a convenções de path e arriscaria não-determinismo no boot.

**Alternativa rejeitada**: autoload via `Zeitwerk`. Adiciona dependência/convenção e esconde a ordem de carga; descartado em favor de `require_relative` explícito gerado.

## Risks / Trade-offs

| Risco | Mitigação |
|---|---|
| Codegen custom é manutenção própria | Escopo mínimo (objects, enums, refs, nullable, oneOf/allOf simples). Documentar patterns suportados no CONTRIBUTING.md |
| Specs OpenAPI da NFE.io são imperfeitos (`nullable` ausente, `oneOf` sem discriminator) | Gerador tolerante: em dúvida, `untyped` + comentário; nunca quebrar o pipeline silenciosamente |
| Specs sem `components.schemas` (`nf-servico-v1`, `cpf-api`) não geram DTOs | DTOs faltantes ficam hand-written em `lib/nfe/resources/dto/`; listados em `openapi/README.md` |
| Drift entre `.rb` e `.rbs` | Gerar ambos do mesmo modelo num único passo; `generate:check` cobre os dois diretórios |
| Não-determinismo na saída gera falso drift no CI | Ordenação estável + isolamento do `generated_at` no marker; teste de idempotência (gerar 2x → bytes idênticos) |
| Specs em `.json` (ex.: `contribuintes-v2.json`) | Normalizar JSON→YAML no sync OU `SpecLoader` aceita ambos via `JSON.parse` |
| Bytes commitados de `lib/nfe/generated/` poluem diffs de PR | `.gitattributes` `linguist-generated=true` em `lib/nfe/generated/**` e `sig/nfe/generated/**` |
| Nomes de schema em camelCase vindos do spec | `NameMapper#class_name`/`#attr_name` normaliza para idioma Ruby; nome original preservado em comentário para rastreabilidade |
| Cross-file `$ref` (não suportado) | Cada spec é self-contained; `$ref` externo → warning + `untyped`; não é caso real nos specs atuais |
| `Data.define` não impõe required em runtime | O rigor required/optional vive na assinatura RBS + Steep; o DTO gerado é anêmico por design |

## Resolved (durante recon — 2026-06-24)

### R1. Specs vivem em nfeio-docs `static/api/`
**Achado**: o conjunto de specs está em `docs/static/api/*.yaml` (símlink `client-ruby/nfeio-docs`), incluindo RTC (`service-invoice-rtc-v1.yaml`, `product-invoice-rtc-v1.yaml`) e Contribuintes v2 — exatamente o source-of-truth, à frente do spec dir do Node SDK.
**Decisão**: `rake openapi:sync` puxa daí; conjunto-base listado em tasks §2.2.

### R2. Alguns specs não têm `components.schemas`
**Achado**: `nf-servico-v1.yaml` tem 0 component schemas (ServiceInvoice é derivado de `operations[...]`); `cpf-api.yaml` idem. O PHP marcou isso para `cpf-api-v3` (DTOs hand-written em c07).
**Decisão**: esses não geram namespace; DTOs faltantes ficam hand-written nas changes de recursos (D15). Registrado em tasks §2.4 e §10.7.

### R3. PHP gerou 415 arquivos em 10 namespaces
**Achado**: a execução real do PHP (`composer generate`) produziu 415 arquivos em `CalculoImpostosV1`, `ConsultaCnpjV3`, `ConsultaCteV2`, `ConsultaDfeDistribuicaoV2`, `ConsultaNfConsumidorV3`, `ConsumerInvoiceV3`, `ContribuintesV2`, `ProductInvoiceRtcV1`, `ProductRegisterPtBrV1`, `ServiceInvoiceRtcV1`.
**Decisão**: ordem de grandeza esperada para o Ruby também (×2 por causa dos `.rbs`). Confirma a necessidade de `linguist-generated=true` e exclusão no RuboCop/Steep.

### R4. Preservar sufixo de versão no namespace (vs Node)
**Achado**: o Node remove a versão (`NfServico`); famílias multi-versão coexistem (`consulta-cnpj` numérico + `consulta-cnpj-v3` alfanumérico do CNPJ alfanumérico de jul/2026).
**Decisão**: preservar versão (`NfServicoV1`, `ConsultaCnpjV3`) como o PHP faz, para evitar colisão entre versões do mesmo domínio (D13).
