# Tasks — add-ruby-foundation

> Plano greenfield. Estabelece a fundação; nenhum recurso de API é implementado aqui (isso vive nas changes seguintes). Paths absolutos relativos à raiz do repo `client-ruby/`.
>
> **Status de implementação (2026-06-24):** fundação implementada e **validada via Docker** (`docker compose`, matrix Ruby 3.2/3.3/3.4) — tudo verde: rspec 14/0 (cobertura de linha 100%), rubocop 0 offenses, steep 0 erros, rbs válido, `gem build` ok, zero deps de runtime. `[x]` = feito/verificado; `[ ] (admin)` = tarefa humana de operação (push/branch protection/RubyGems). Legado preservado em `0.x-legacy` (`4a8ad8f`). Implementação feita no branch de trabalho atual (`next`); consolidação para `master` conforme política (1.3) fica a critério do mantenedor.

## 1. Branch & política de manutenção

- [x] 1.1 Snapshot do `master` atual (v0.3.2, baseado em rest-client) para o branch `0.x-legacy` (`git branch 0.x-legacy master` antes de qualquer remoção)
- [ ] 1.2 Push do branch `0.x-legacy` e marcá-lo como congelado (sem manutenção, sem backports) — **DEFERRED (admin; humano roda `git push -u origin 0.x-legacy`)**
- [x] 1.3 Desenvolver a v1 substituindo o conteúdo legado — **feito no branch `next`; mover/abrir PR para `master` é decisão do mantenedor**
- [ ] 1.4 Configurar branch protection no GitHub: `master` aceita PRs com CI verde — **DEFERRED (admin, GitHub UI)**
- [ ] 1.5 Configurar publicação no RubyGems do nome `nfe-io` 1.0.0 — **DEFERRED (admin, change de release)**

## 2. Limpeza do legado

- [x] 2.1 Remover a árvore legada: `lib/nfe/service_invoice.rb`, `lib/nfe/api_resource.rb`, `lib/nfe/nfe_object.rb`, `lib/nfe/util.rb`, `lib/nfe/company.rb`, `lib/nfe/configuration.rb`, `lib/nfe/version.rb`, `lib/nfe/natural_people.rb`, `lib/nfe/legal_people.rb`, `lib/nfe/api_operations/*`, `lib/nfe/errors/nfe_error.rb` (configuration/version reescritos; demais removidos — preservados em `0.x-legacy`)
- [x] 2.2 Remover `lib/data/ssl-bundle.crt` (usaremos o bundle de CA do OpenSSL/stdlib, sem bundle versionado)
- [x] 2.3 Remover `.travis.yml` e `.ruby-gemset`
- [x] 2.4 Esvaziar `spec/` legado (reescrito com RSpec moderno)
- [x] 2.5 Manter `LICENSE.txt` (MIT) intacta

## 3. Gemspec & metadados

- [x] 3.1 Reescrever `nfe-io.gemspec` (renomeado de `nfe.gemspec`): name `nfe-io`, version `Nfe::VERSION` (1.0.0), `required_ruby_version >= 3.2`, summary/description, homepage, license MIT, metadata (homepage/source/changelog/bug_tracker + `rubygems_mfa_required`), authors NFE.io Team / suporte@nfe.io
- [x] 3.2 **Zero `add_dependency`** (nenhuma dep de runtime) — `rest-client` removido
- [x] 3.3 `add_development_dependency` apenas: `rake`, `rspec`, `rubocop`, `rubocop-rspec`, `rbs`, `steep`, `simplecov`
- [x] 3.4 `spec.files`: `lib/**/*.rb`, `sig/**/*.rbs`, `README.md`, `MIGRATION.md`, `CHANGELOG.md`, `LICENSE.txt`
- [x] 3.5 `spec.require_paths = ["lib"]`; sem `bindir`/`exe`
- [x] 3.6 Criar `lib/nfe/version.rb` com `module Nfe; VERSION = "1.0.0"; end` + `# frozen_string_literal: true`

## 4. Layout `lib/` & namespace

- [x] 4.1 `lib/nfe.rb` entrypoint: `# frozen_string_literal: true`, requires (`version`/`configuration`/`flow_status`/`client`), `module Nfe`
- [x] 4.2 Árvore *hand-written*: `lib/nfe/`, `lib/nfe/resources/`, `lib/nfe/errors/`, `lib/nfe/http/` (placeholders com `.gitkeep` documentado)
- [x] 4.3 `lib/nfe/generated/` reservado para value objects gerados (NUNCA editar à mão); `.gitkeep` explicando a origem
- [x] 4.4 `lib/nfe/configuration.rb` como fonte única do mapa multi-base-URL (`base_url_for`): main→api.nfe.io, addresses→address.api.nfe.io/v2, nfe-query→nfe.api.nfe.io, legal-entity→legalentity.api.nfe.io, natural-person→naturalperson.api.nfe.io, cte→api.nfse.io, desconhecida→main
- [x] 4.5 `lib/nfe/client.rb` com `Nfe::Client.new(api_key:, data_api_key:, environment:, base_url:, timeout:, retry_config:)` e os 17 acessores lazy `snake_case` (stubs nesta change; corpos nas seguintes)
- [x] 4.6 `# frozen_string_literal: true` como **primeira linha** de todo `.rb` (verificado)

## 5. Value objects com `Data.define`

- [x] 5.1 Convenção: modelos imutáveis usam `Data.define(...)` (Ruby 3.2+), keyword args, `snake_case`
- [x] 5.2 Exemplo de referência: `lib/nfe/flow_status.rb` — estados terminais (`Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`) e não-terminais + `terminal?`
- [x] 5.3 Documentar no `project.md`: downloads retornam `String` binária (`ASCII_8BIT`) e o contrato 202 discriminado (Pending/Issued) será modelado nos recursos

## 6. RBS & assinaturas de tipo

- [x] 6.1 Layout `sig/` espelhando `lib/`: `sig/nfe.rbs`, `sig/nfe/version.rbs`, `sig/nfe/client.rbs`, `sig/nfe/configuration.rbs`, `sig/nfe/flow_status.rbs`
- [x] 6.2 `sig/nfe/generated/` reservado (par com `lib/nfe/generated/`); `.gitkeep`
- [x] 6.3 Assinaturas RBS dos artefatos de fundação (`VERSION`, `Client.new`, 17 acessores, `Configuration#base_url_for`, `FlowStatus`)
- [x] 6.4 `rbs validate` passa (verificado via docker 3.2/3.3/3.4)

## 7. Steep (type-check)

- [x] 7.1 `Steepfile` com `target :lib`, `check "lib"`, `signature "sig"`
- [x] 7.2 `ignore "lib/nfe/generated"` no check estrito inicial
- [x] 7.3 `bundle exec steep check` verde (verificado via docker 3.2/3.3/3.4)

## 8. RuboCop (lint/estilo)

- [x] 8.1 `.rubocop.yml`: `plugins: rubocop-rspec` (API 3.x); `TargetRubyVersion: 3.2`; `NewCops: enable`
- [x] 8.2 `Style/FrozenStringLiteralComment: EnforcedStyle: always`
- [x] 8.3 Excluir `lib/nfe/generated/**/*`, `bin/**/*` e symlinks de referência
- [x] 8.4 Calibrar cops de métrica (Method/Abc/Class/Block) com limites razoáveis
- [x] 8.5 `bundle exec rubocop` verde — 0 offenses (verificado via docker 3.2/3.3/3.4)

## 9. RSpec & SimpleCov

- [x] 9.1 `.rspec` com `--require spec_helper`, `--format documentation`, `--color`
- [x] 9.2 `spec/spec_helper.rb` carrega SimpleCov **antes** do código (`add_filter` spec/generated, `minimum_coverage 80`)
- [x] 9.3 Specs smoke: `version_spec.rb`, `client_spec.rb` (17 acessores + stub), `configuration_spec.rb` (host map + fallback), `flow_status_spec.rb`
- [x] 9.4 Cobertura >= 80% verificada — 100% de linha (verificado via docker 3.2/3.3/3.4)

## 10. Gemfile & Rakefile

- [x] 10.1 `Gemfile`: `source`, `gemspec`, `# frozen_string_literal: true`
- [x] 10.2 `Rakefile`: tarefas `spec`/`rubocop`/`steep`/`rbs`; `task default: %i[spec rubocop steep rbs]`
- [x] 10.3 `.ruby-version` apontando `3.4` (piso suportado 3.2)

## 11. CI (GitHub Actions)

- [x] 11.1 `.github/workflows/ci.yml` em `push`/`pull_request` no `master`
- [x] 11.2 Matrix `ruby-version: ['3.2','3.3','3.4']` com `ruby/setup-ruby` + `bundler-cache: true`
- [x] 11.3 Steps: `rspec` (cobertura), `rubocop`, `steep check`, `rbs validate`
- [x] 11.4 Gate de cobertura via `minimum_coverage` (exit code != 0)
- [x] 11.5 CI só no `master`; ignora `0.x-legacy`
- [x] 11.6 Badge de status no `README.md`

## 12. Documentação base

- [x] 12.1 `README.md`: banner "v1 em desenvolvimento", status legado, exemplo `Nfe::Client.new`, tabela dos 17 recursos por grupo, nota zero-dep
- [x] 12.2 `MIGRATION.md`: tabela v0.x→v1 (entrypoint, remoção rest-client, value objects), aviso de breaking total / sem backports
- [x] 12.3 `CHANGELOG.md` formato Keep-a-Changelog com `[Unreleased]` / `[0.3.2]`
- [x] 12.4 `.gitignore`: `pkg/`, `coverage/`, `.bundle/`, `Gemfile.lock`, `.steep/`, `*.gem`, `.rbs_collection.*`

## 13. `openspec/project.md`

- [x] 13.1 `openspec/project.md` (contexto Ruby): Purpose, Tech Stack, Conventions, Domain, Constraints, Dependencies, Useful Files & Commands
- [x] 13.2 Documenta mapa multi-base-URL como fonte única, contrato 202, FlowStatus terminal, downloads `String` binária, `lib/nfe/generated/` nunca editado à mão

## 14. Validação

- [x] 14.1 `bundle install` em Ruby 3.2 limpo — sem deps de runtime (docker: 53 gems, todos dev)
- [x] 14.2 `bundle exec rspec` — 14 exemplos / 0 falhas, cobertura de linha 100% (docker 3.2/3.3/3.4)
- [x] 14.3 `bundle exec rubocop` — 0 ofensas (docker 3.2/3.3/3.4)
- [x] 14.4 `bundle exec steep check` — 0 erros (docker 3.2/3.3/3.4)
- [x] 14.5 `bundle exec rbs validate` — assinaturas válidas (docker 3.2/3.3/3.4)
- [x] 14.6 `gem build nfe-io.gemspec` — empacota `nfe-io-1.0.0.gem`; `runtime_dependencies == []` confirmado
- [x] 14.7 `openspec validate add-ruby-foundation` — passa (`--strict`)
