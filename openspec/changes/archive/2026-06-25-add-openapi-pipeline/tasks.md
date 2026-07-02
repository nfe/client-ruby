# Tasks — add-openapi-pipeline

> Depende de `add-ruby-foundation` (gem `nfe-io` 1.0.0, namespace `Nfe`, piso Ruby 3.2, zero-dep de runtime, RBS/Steep/RuboCop/RSpec, CI matrix 3.2/3.3/3.4). Esta pipeline é consumida por `add-invoice-resources` e demais changes de recursos, que hidratam os `Data.define` gerados.
>
> **Status (2026-06-25): IMPLEMENTADO e verificado verde via Docker na matrix Ruby 3.2/3.3/3.4.** Gerador dev-only (`scripts/generator/*`, stdlib Psych/Digest, zero gem externa) + entry `scripts/generate.rb`; 18 specs sincronizados em `openapi/` (de `nfeio-docs`); `rake generate`/`generate:check`/`openapi:sync`; gerado em `lib/nfe/generated/**` (excluído de RuboCop/Steep-estrito, marcado `linguist-generated`) + sigs em `sig/nfe/generated/**` (validadas por `rbs validate`). Gate: rspec 213/0 (cobertura ~98%), rubocop 0, steep 0, rbs ok, **generate:check in-sync** — nos três Rubies. Geração real: **1100 arquivos, 11 namespaces** (7 specs sem `components.schemas` pulados). Bugs corrigidos na verificação: `class_name` agora capitaliza (constante válida p/ schemas camelCase); `$ref` resolve para o tipo real do alvo (primitivo→`Integer`, objeto→classe, enum/livre→`untyped`/`Hash`); primitivos top-level não viram mais `= Hash`; loader `lib/nfe/generated.rb` excluído do RuboCop. §1.3 (emissor): template-string determinístico, sem `prism` (zero dep). §11.2/§11.3 (CONTRIBUTING/MIGRATION) diferidos para `add-release-tooling`.

## 1. Dependências dev-only (grupo :codegen)

- [ ] 1.1 Adicionar grupo `:codegen` no `Gemfile` (ou `group :codegen do ... end`) com as deps de build-time; **garantir que nada disso entra no `nfe-io.gemspec`** (`add_dependency` permanece vazio — zero runtime dep).
- [ ] 1.2 Usar `psych` (stdlib em Ruby 3.2+) como parser YAML primário — `require "psych"`. Documentar que NÃO é dependência de gem externa.
- [ ] 1.3 Decidir o emissor de código: `prism` (parser/emitter oficial Ruby 3.3+, dev-only) OU template-string com normalização determinística (sem dep). Registrar a decisão final em design.md §D3 e aplicar consistentemente.
- [ ] 1.4 Verificar que `bundle install --without codegen` produz um ambiente de runtime sem nenhuma dep de geração (smoke do isolamento dev-only).

## 2. Inventário de specs (sync do nfeio-docs)

- [ ] 2.1 Criar diretório `openapi/` no repo.
- [ ] 2.2 Sincronizar o conjunto de specs de `nfeio-docs` (`docs/static/api/*.yaml`) para `openapi/`. Conjunto-base (mesmas famílias de Node/PHP):
  - `nf-servico-v1.yaml` (NFS-e clássico, host api.nfe.io)
  - `nf-produto-v2.yaml` (NF-e clássico, host api.nfse.io)
  - `nf-consumidor-v2.yaml` (NFC-e, host api.nfse.io)
  - `consulta-nf.yaml` (consulta NF-e por chave de acesso)
  - `consulta-nf-consumidor.yaml` (consulta cupom NFC-e)
  - `consulta-cte-v2.yaml` (inbound CT-e)
  - `consulta-nfe-distribuicao-v1.yaml` (distribuição inbound NF-e v1)
  - `consulta-dfe-distribuicao-v2.yaml` (distribuição inbound NF-e v2, mais nova)
  - `consulta-cnpj.yaml` / `consulta-cnpj-v3.yaml` (CNPJ lookup; v3 = CNPJ alfanumérico)
  - `cpf-api.yaml` / `cpf-api-v3.yaml` (CPF lookup)
  - `consulta-endereco.yaml` / `consulta-endereco-v3.yaml` (CEP lookup)
  - `calculo-impostos-v1.yaml` (motor de cálculo de impostos)
  - `service-invoice-rtc-v1.yaml` (NFS-e RTC — Reforma Tributária, IBS/CBS/IS)
  - `product-invoice-rtc-v1.yaml` (NF-e/NFC-e RTC)
  - `contribuintes-v2.yaml` (Company Management unificado v2)
  - `product-register-pt-br-v1.yaml` (catálogo de produtos)
  - `nfeio.yaml` (Batch Processor / jobs / notificações)
- [ ] 2.3 Documentar quais specs vêm como JSON (ex.: `consumer-invoice.json`, `contribuintes-v2.json` existem no docs) e normalizar para YAML no sync, OU suportar `.json` no loader. Registrar decisão.
- [ ] 2.4 Anotar specs sem `components.schemas` (ex.: `nf-servico-v1` deriva schema de `operations[...]`; `cpf-api` sem schemas) — esses NÃO produzem namespace; os DTOs faltantes ficam hand-written nas changes de recursos. Listar em `openapi/README.md`.
- [ ] 2.5 Criar `openapi/README.md` registrando: fonte (nfeio-docs `docs/static/api/`), data do snapshot, e a regra "specs são copiados manualmente após revisão".

## 3. Sync-from-docs (mecanismo documentado)

- [ ] 3.1 Criar task `rake openapi:sync` que copia `nfeio-docs/static/api/*.{yaml,json}` (caminho configurável via env `NFEIO_DOCS_PATH`) para `openapi/`, normalizando JSON→YAML quando aplicável, e reportando o diff de arquivos.
- [ ] 3.2 `rake openapi:sync` NÃO faz commit nem dispara `generate` automaticamente — apenas atualiza os YAMLs para revisão humana.
- [ ] 3.3 Seção em `CONTRIBUTING.md`: "Como atualizar specs OpenAPI" — passos: `rake openapi:sync` → revisar diff → `rake generate` → revisar `lib/nfe/generated/` + `sig/nfe/generated/` → commit dos três (specs + .rb + .rbs) juntos.
- [ ] 3.4 Registrar que o source-of-truth é nfeio-docs e que o Node SDK está atrás dos docs (RTC e v3 ainda não estão no spec dir do Node) — o Ruby sincroniza direto dos docs.

## 4. Estrutura do gerador

- [ ] 4.1 Criar `scripts/generate.rb` com shebang `#!/usr/bin/env ruby`, `# frozen_string_literal: true`, parse de args (`--check`, `--spec <name>`, `--verbose`), e require do diretório `scripts/generator/`.
- [ ] 4.2 Criar `scripts/generator/spec_loader.rb` — `Nfe::Build::SpecLoader`: lê YAML via Psych, valida shape mínimo (chave `openapi`/`swagger` presente, `components.schemas` é Hash), expõe `#schemas` (Hash nome→schema), `#path`, `#hash` (SHA-256 do conteúdo bruto via `Digest::SHA256`). Falha alta (`raise`) em spec quebrado.
- [ ] 4.3 Criar `scripts/generator/name_mapper.rb` — `Nfe::Build::NameMapper`: `namespace_from_spec("service-invoice-rtc-v1.yaml") => "ServiceInvoiceRtcV1"` (kebab→PascalCase, preserva `v1`→`V1`); `module_path_from_spec(...) => "service_invoice_rtc_v1"` (snake_case do filename, para diretório/require); `class_name(schema_name)` (defensivo: caracteres inválidos → `_`, prefixa `_` se começar com dígito); `attr_name(prop)` (camelCase/PascalCase do spec → snake_case idiomático Ruby).
- [ ] 4.4 Criar `scripts/generator/type_mapper.rb` — `Nfe::Build::TypeMapper`: schema-fragment → tipo RBS + nota. Mapeia primitivos (`string`→`String`, `integer`→`Integer`, `number`→`Float`, `boolean`→`bool`, `object` free-form→`Hash[String, untyped]`), `$ref` local→nome de classe na mesma família, `array`→`Array[T]`, `nullable`/opcional→`T?`, `oneOf` de primitivos→union RBS (`Integer | String`), `oneOf`/`allOf` complexos→`untyped` com comentário. Conservador: em dúvida, `untyped`.
- [ ] 4.5 Criar `scripts/generator/schema_compiler.rb` — `Nfe::Build::SchemaCompiler`: schema `object` → modelo interno de um `Data.define` (lista ordenada de `{ruby_name, original_name, ruby_type, rbs_type, nullable, required, doc}`). Required sem default; opcional com `= nil` (ou keyword default `nil`).
- [ ] 4.6 Criar `scripts/generator/enum_compiler.rb` — `Nfe::Build::EnumCompiler`: schema com `enum: [...]` → modelo de módulo de constantes congeladas; retorna `nil` se o schema não for enum. Suporta backing String e Integer; nomeia constantes a partir dos valores (PascalCase/UPPER_SNAKE) com colisão resolvida deterministicamente.
- [ ] 4.7 Criar `scripts/generator/ruby_emitter.rb` — `Nfe::Build::RubyEmitter`: modelo → string `.rb` (banner + `module Nfe; module Generated; module <Family>; <Const> = Data.define(...) end end end`). Indentação e ordenação determinísticas.
- [ ] 4.8 Criar `scripts/generator/rbs_emitter.rb` — `Nfe::Build::RbsEmitter`: mesmo modelo → string `.rbs` (banner em comentário + `module Nfe; module Generated; module <Family>; class <Const> ... end end end end`) com atributos tipados e assinatura do construtor `Data.define`.
- [ ] 4.9 Criar `scripts/generator/generator.rb` — `Nfe::Build::Generator`: orquestra (descobre specs em `openapi/`, carrega, compila, emite). `#generate => Hash[rel_path => contents]` (em memória, para check mode) cobrindo `.rb` E `.rbs`; `#write_to(lib_root, sig_root) => Array[paths]`.
- [ ] 4.10 Criar `scripts/generator/check_mode.rb` — `Nfe::Build::CheckMode.diff(generator, lib_root, sig_root) => {ok:, added:, removed:, changed:}`: compara saída esperada (em memória) com o checked-in nos dois diretórios; ordena listas; `ok` true só se vazio em todos.

## 5. Compilação de tipos (regras de mapeamento)

- [ ] 5.1 Primitivos: `string`→`String`, `integer`→`Integer`, `number`→`Float`, `boolean`→`bool` (RBS), `object` (free-form)→`Hash[String, untyped]`.
- [ ] 5.2 `nullable: true` (ou propriedade opcional não-required) → tipo RBS `T?` e keyword arg com default `nil` no `Data.define`.
- [ ] 5.3 `$ref` local (`#/components/schemas/Foo`) → resolve para `Foo` (mesma família/módulo). Cross-file `$ref` não suportado (cada spec é self-contained); logar warning e cair para `untyped`.
- [ ] 5.4 `format: date-time` / `date` → `String` (fiel ao wire ISO 8601; conversão para `Time` fica em helpers da camada de recursos, não no DTO gerado).
- [ ] 5.5 `array` com `items` → `Array[ItemType]`; sem `items` → `Array[untyped]`.
- [ ] 5.6 `oneOf` entre primitivos → union RBS (`Integer | String`); keyword arg Ruby aceita ambos.
- [ ] 5.7 `oneOf`/`anyOf` entre objetos → `untyped` com comentário `# oneOf: A | B` (sem discriminator confiável nos specs).
- [ ] 5.8 `allOf` → merge raso das propriedades dos membros (composição); colisão de propriedade resolve para o último membro com warning.
- [ ] 5.9 Required vs opcional: campos em `required: [...]` viram keyword args obrigatórios (sem default); demais ganham default `nil`.
- [ ] 5.10 Nomes de propriedade: spec frequentemente usa camelCase (`federalTaxNumber`); `Data.define` usa snake_case idiomático (`federal_tax_number`). O `RubyEmitter` registra o nome original em comentário para rastreabilidade; a hidratação (camada de recursos) faz o mapeamento camel→snake.
- [ ] 5.11 `additionalProperties` / objetos sem propriedades nomeadas → não gerar `Data.define` vazio; cair para alias `Hash[String, untyped]` com comentário.

## 6. Layout de saída e banner

- [ ] 6.1 `lib/nfe/generated/<module_path>/<schema_snake>.rb` — 1 `Data.define` por arquivo, autoload-friendly.
- [ ] 6.2 `sig/nfe/generated/<module_path>/<schema_snake>.rbs` — 1 assinatura por arquivo, espelhando 1:1 o `.rb`.
- [ ] 6.3 Banner em todo `.rb`:
  ```ruby
  # frozen_string_literal: true
  # AUTO-GENERATED — do not edit
  # Source: openapi/<spec>.yaml
  # Hash: sha256:<hash>
  ```
- [ ] 6.4 Banner equivalente em todo `.rbs` (comentários `#`).
- [ ] 6.5 `lib/nfe/generated/generated_marker.rb` — `module Nfe; module Generated; MARKER = { generated_at: "...", specs: { "<spec>" => "sha256:..." } }.freeze; end; end`. O `generated_at` NÃO entra no corpo comparado pelo check mode (ou é normalizado), para manter determinismo.
- [ ] 6.6 Garantir `# frozen_string_literal: true` como primeira linha de TODO `.rb` gerado (regra de `add-ruby-foundation`).
- [ ] 6.7 Saída determinística: ordenar schemas e propriedades por nome; nenhuma fonte de não-determinismo (sem timestamp no corpo comparado, sem ordem de Hash dependente de inserção).

## 7. Mapeamento para Ruby idiomático

- [ ] 7.1 `object` schema → `Const = Data.define(:attr_a, :attr_b, ...)` com keyword constructor (Ruby `Data.define` aceita posicional E keyword; documentar uso keyword na hidratação).
- [ ] 7.2 Value objects imutáveis por construção (`Data.define` é frozen) — alinha com a decisão canônica "immutable Data.define value objects".
- [ ] 7.3 `enum` → `module <Const>; ValueA = "a"; ValueB = "b"; ALL = [ValueA, ValueB].freeze; end` (constantes congeladas; sem dependência de runtime). RBS correspondente declara as constantes com seus tipos literais quando possível.
- [ ] 7.4 Namespaces: `module Nfe; module Generated; module <Family>; ... end end end` — 1 família por spec, nome derivado mecanicamente (`NfServicoV1`, `NfProdutoV2`, `NfConsumidorV2`, `ConsultaCteV2`, `ConsultaDfeDistribuicaoV2`, `CalculoImpostosV1`, `ConsultaCnpjV3`, `ServiceInvoiceRtcV1`, `ProductInvoiceRtcV1`, `ContribuintesV2`, etc.).
- [ ] 7.5 Modelos anêmicos: apenas atributos imutáveis, sem lógica de negócio. O único método gerado é `from_api` (§7.7). Polling, downloads e demais helpers vivem nas changes de recursos.
- [ ] 7.6 `require` interno: cada arquivo gerado é self-contained (sem `require` de gem externa). **Decisão (D17): loader por `require_relative` explícito** — o gerador emite `lib/nfe/generated.rb` que faz `require_relative` de cada arquivo gerado em ordem estável; sem autoload mágico.
- [ ] 7.7 `from_api(payload)` em cada `Data.define` (GAP#7): mapeia chaves camelCase→membros snake_case, descarta chaves desconhecidas, recursa em atributos `$ref` (objeto → `from_api` do DTO referenciado; array de `$ref` → `map` elemento a elemento). Primitivos e `Hash` free-form atribuídos como estão. É o único método gerado no value object. Emitir a assinatura `.rbs` correspondente (`def self.from_api: (Hash[String, untyped] payload) -> instance`) no mesmo passo (template fixo de D17).

## 8. Rake tasks + integração CI

- [ ] 8.1 Adicionar no `Rakefile`: `task :generate` → `ruby scripts/generate.rb`; `namespace :generate { task :check => ... }` → `ruby scripts/generate.rb --check`.
- [ ] 8.2 Adicionar `task "openapi:sync"` (§3.1).
- [ ] 8.3 Job `openapi-sync` em `.github/workflows/ci.yml` (reutiliza a matrix/checkout de `add-ruby-foundation`): roda `bundle install` (com grupo `:codegen`) e `rake generate:check`; falha o PR se houver drift.
- [ ] 8.4 `.rubocop.yml`: `AllCops.Exclude` inclui `lib/nfe/generated/**/*` (gerado tolera shapes amplos; o lint estrito permanece na superfície hand-written).
- [ ] 8.5 `Steepfile`: `check "lib/nfe/generated"` excluído do alvo estrito OU configurado em nível mais frouxo; as assinaturas geradas em `sig/nfe/generated/` ainda são carregadas para que a camada hand-written tipe contra elas.
- [ ] 8.6 `.gitattributes`: `lib/nfe/generated/** linguist-generated=true` e `sig/nfe/generated/** linguist-generated=true` (esconde diffs gerados no GitHub).
- [ ] 8.7 Confirmar que `rake generate:check` cobre AMBOS os diretórios (`lib/nfe/generated/` e `sig/nfe/generated/`).

## 9. Testes (RSpec)

- [ ] 9.1 Fixture mínima `spec/fixtures/openapi/minimal.yaml` — exercita: `object` com required+opcional, `$ref`, `array` de `$ref`, `enum` string, `enum` integer, `nullable`, `oneOf` de primitivos, propriedade camelCase.
- [ ] 9.2 `spec/generator/spec_loader_spec.rb` — parse OK, validação de shape, `#schemas`, `#hash` estável, raise em YAML quebrado e em spec sem `components.schemas`.
- [ ] 9.3 `spec/generator/name_mapper_spec.rb` — `namespace_from_spec`, `module_path_from_spec`, `class_name` defensivo, `attr_name` camel→snake.
- [ ] 9.4 `spec/generator/type_mapper_spec.rb` — primitivos, `$ref`, `array`, `nullable`→`?`, `oneOf` primitivos→union, `oneOf` objetos→`untyped`, `date-time`→`String`.
- [ ] 9.5 `spec/generator/schema_compiler_spec.rb` — required sem default, opcional com `nil`, ordenação estável, `allOf` merge, nome reservado.
- [ ] 9.6 `spec/generator/enum_compiler_spec.rb` — backing string/int, não-enum retorna `nil`, colisão de constante resolvida.
- [ ] 9.7 `spec/generator/ruby_emitter_spec.rb` — banner presente, `# frozen_string_literal: true` na linha 1, `Data.define` correto, `from_api` emitido, eval do output produz constante carregável.
- [ ] 9.7.1 `spec/generator/from_api_spec.rb` (GAP#7) — eval do DTO gerado e exercitar `from_api`: camelCase→snake_case, chave desconhecida descartada sem raise, objeto `$ref` aninhado hidratado no DTO, array de `$ref` mapeado elemento a elemento, `nil` tolerado.
- [ ] 9.8 `spec/generator/rbs_emitter_spec.rb` — banner, sintaxe RBS válida (parse via `rbs` se disponível), atributos espelham o `.rb`.
- [ ] 9.9 `spec/generator/generator_spec.rb` — `generate` retorna `.rb` + `.rbs`, `write_to` escreve nos dois diretórios, idempotência (gerar 2x → bytes idênticos).
- [ ] 9.10 `spec/generator/check_mode_spec.rb` — sem drift→`ok:true`; arquivo alterado→`changed`; arquivo faltante→`added`; arquivo extra→`removed`.
- [ ] 9.11 Cobertura SimpleCov >= 80% no diretório `scripts/generator/` (alinhado ao piso de `add-ruby-foundation`).

## 10. Execução real (geração inicial)

- [x] 10.1 `rake generate` rodado contra os specs sincronizados — **1100 arquivos** (550 `.rb` + 549 `.rbs` + loader + marker), **11 namespaces** (docker 3.2/3.3/3.4).
- [x] 10.2 Amostrado `ServiceInvoiceRtcV1`/`ProductInvoiceRtcV1`/`NfProdutoV2`/`NfConsumidorV2` — banner, namespace, `Data.define` + `from_api`, e `.rbs` conferidos.
- [ ] 10.3 Commitar `openapi/*` + `lib/nfe/generated/**` + `sig/nfe/generated/**` no MESMO commit — **a critério do mantenedor (nada commitado ainda)**.
- [x] 10.4 `steep check` 0 erros (gerado ignorado do alvo estrito, sigs geradas carregadas) — docker 3.2/3.3/3.4.
- [x] 10.5 `rubocop` 0 ofensas (gerado + loader excluídos) — docker 3.2/3.3/3.4.
- [x] 10.6 `rake generate:check` → "Generated output is in sync" — docker 3.2/3.3/3.4.
- [x] 10.7 Specs sem `components.schemas` anotados (gerador loga; listados em `openapi/README.md`): `consulta-cnpj`, `consulta-endereco`, `consulta-nf-v3`, `consulta-nf`, `consumer-invoice.json`, `cpf-api`, `nf-servico-v1`.

## 11. Documentação

- [x] 11.1 `lib/nfe/generated/README.md` — explica geração, regeneração (`rake generate`) e a regra "não editar à mão".
- [ ] 11.2 `CONTRIBUTING.md` — fluxo de sync + patterns/limites OpenAPI — **DEFERRED para `add-release-tooling`** (dona do `CONTRIBUTING.md`).
- [ ] 11.3 Nota em `MIGRATION.md` (tipos agora em `Nfe::Generated::*`) — **DEFERRED para `add-release-tooling`** (consolidação da migração).

## 12. Validação OpenSpec

- [x] 12.1 `openspec validate add-openapi-pipeline --strict` passa.
- [x] 12.2 Referências cruzadas a `add-ruby-foundation` conferidas na prosa (proposal/design).
