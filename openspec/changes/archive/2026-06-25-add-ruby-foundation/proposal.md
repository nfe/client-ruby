# add-ruby-foundation

## Why

A gem `nfe-io` atual (v0.3.2) está **anos sem manutenção** e foi escrita para um Ruby muito antigo (`.ruby-version` aponta `ruby-2.4.1`). Sintomas concretos do código legado:

- Dependência de runtime de **`rest-client ~> 2.0.2`** (HTTP de terceiros)
- Estado global mutável via variável de classe `@@api_key`
- Sem tipos, sem RBS, sem `frozen_string_literal`
- Objetos de domínio dinâmicos (`Nfe::NfeObject` com `method_missing`), sem value objects imutáveis
- Cobertura mínima de recursos (apenas `service_invoice`, `company`, `legal_people`, `natural_people`)
- `bundler ~> 1.10`, `rake ~> 10.0` — toolchain pré-2016
- CI via `.travis.yml` (desligado)

Para alcançar paridade com os SDKs de referência — Node.js (`nfe-io`, zero-dep, TypeScript) e PHP (`nfe/client-php`, PHPStan L8) — e seguir a filosofia Stripe (cliente único + acessores de recurso *lazy*, ergonomia *hand-crafted* sobre modelos gerados), o caminho não é refatorar incremental. É um **rewrite greenfield v1 com piso Ruby 3.2+**, nada reaproveitado do código atual.

Esta change estabelece a fundação. Ela **não entrega valor de runtime** sozinha — só viabiliza as changes seguintes (HTTP core, codegen de OpenAPI, `Nfe::Client`, recursos). É a primeira change do grafo; não depende de nenhuma outra.

## What Changes

- **Gem name**: permanece `nfe-io` (sem rename — diferente do PHP). Bump de major **0.3.2 → 1.0.0**
- **Ruby requirement**: `required_ruby_version >= 3.2` (drop 2.x/3.0/3.1)
- **Zero deps de runtime**: remover `rest-client`; usar **somente stdlib** (`net/http`, `json`, `openssl`, `uri`, `securerandom`, `stringio`, `time`, `base64`)
- **Namespace raiz**: `Nfe`; entrypoint único `Nfe::Client.new(api_key: "...")` (estilo Stripe), com acessores de recurso `snake_case` *lazy* (ex.: `client.service_invoices`)
- **Layout**: código *hand-written* em `lib/nfe/...`; modelos gerados em `lib/nfe/generated/`; assinaturas RBS em `sig/`
- **`frozen_string_literal: true`** como primeira linha de **todo** arquivo `.rb`
- **Value objects** imutáveis via `Data.define` (Ruby 3.2+) — substitui o `NfeObject` dinâmico do legado
- **Dev tooling**: `rspec`, `rubocop`, `rbs`, `steep`, `simplecov` (dev-only; zero impacto no pacote publicado)
- **Type rigor**: shipar assinaturas RBS, type-check com Steep no CI, lint com RuboCop, cobertura SimpleCov **>= 80%**
- **Branch strategy**: snapshot do master atual (v0.3.2, baseado em rest-client) para branch **`0.x-legacy`** congelado; v1 desenvolvido em **`master`**
- **CI**: GitHub Actions com matrix **Ruby 3.2 / 3.3 / 3.4** rodando `rspec` + `rubocop` + `steep check` + `rbs validate` + gate de cobertura SimpleCov >= 80%
- **Arquivos de fundação**: `nfe-io.gemspec` reescrito, `Gemfile`, `Rakefile`, `.ruby-version`, `.rubocop.yml`, `Steepfile`, `sig/` layout, `.rspec`, `.github/workflows/ci.yml`
- **`MIGRATION.md`** stub (v0.x → v1, breaking total, sem backports)
- **`README.md`** com marcador "v1 em desenvolvimento" e status do legado
- **`LICENSE`** mantida (MIT)
- **`openspec/project.md`**: contexto do projeto Ruby (propósito, stack, convenções, arquitetura, testes, git, release, domínio, constraints)
- **Não** importar nenhum arquivo de `lib/nfe/*` legado para a v1 — `lib/nfe/` nasce limpo

## Capabilities

### New Capabilities
- `sdk-foundation`: versionamento, namespace, layout, requirements de runtime/dev, toolchain de tipos, CI matrix e política de branch/manutenção do SDK Ruby v1

### Modified Capabilities
- (nenhuma — o repositório ainda não tem specs versionadas em `openspec/specs/`)

## Impact

- **Affected code**: nasce `lib/nfe/` (limpo), `nfe-io.gemspec` reescrito, `Gemfile`, `Rakefile`, `.ruby-version`, `.rubocop.yml`, `Steepfile`, `sig/`, `.rspec`, `.github/workflows/ci.yml`, `MIGRATION.md`, `README.md`; remoção de `.travis.yml`, `.ruby-gemset`, `lib/data/ssl-bundle.crt` e de toda a árvore `lib/nfe/*` legada
- **Backwards compatibility**: **quebra total**. A v1 não reusa nada da v0.3.2. Quem precisa do código antigo fixa `gem "nfe-io", "~> 0.3"` (instala do branch `0.x-legacy`, congelado)
- **Dependencies**: **zero deps de runtime** (remoção definitiva do `rest-client`). Novas deps **dev-only** (`rspec`, `rubocop`, `rbs`, `steep`, `simplecov`) não entram no pacote publicado
- **Downstream**: integrações que hoje fazem `require "nfe"` + `Nfe.api_key(...)` quebram na v1 (`require "nfe"` continua válido como entrypoint, mas a API passa a ser `Nfe::Client.new(api_key:)`). Migração é trabalho de leitura do `MIGRATION.md`
- **Dependencies entre changes**: esta é a change **foundational** — não depende de nenhuma outra; todas as changes subsequentes (HTTP core, codegen, client, recursos) dependem dela
- **Risco aberto**: confirmar política pública do legado — "frozen indefinido" (escolhido) vs. EOL com data formal
