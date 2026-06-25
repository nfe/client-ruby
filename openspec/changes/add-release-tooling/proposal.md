# add-release-tooling

## Why

As changes anteriores (`add-ruby-foundation`, `add-http-transport`, `add-openapi-pipeline`, `add-client-core`, `add-entity-resources`, `add-invoice-resources`, `add-rtc-invoice-emission`, `add-lookup-resources`) entregam o SDK **funcionalmente completo**: gem `nfe-io` com zero dependências de runtime, `Nfe::Client.new(api_key:)` estilo Stripe, 17 recursos snake_case, modelos `Data.define` gerados de OpenAPI, assinaturas RBS, Steep, RuboCop e RSpec com cobertura ≥ 80%.

**Esta change fecha a release** — é a última do bump 0.3.2 → 1.0.0. Sem ela o SDK está pronto mas ninguém consegue:

1. **Instalar** via `gem install nfe-io` / `bundle add nfe-io` — o `nfe-io.gemspec` legado ainda declara `rest-client` e metadados de 2017 (Ruby 2.4.1, autor antigo, homepage `pluga.co`).
2. **Migrar** do v0.3.x (global `Nfe.api_key("...")`, rest-client, classes achatadas) sem ler o código — falta um `MIGRATION.md` exaustivo.
3. **Avaliar** sem mergulhar no código — faltam `samples/` runnable e um `README.md` com quickstart por recurso.
4. **Cortar** uma release semver sem ritual manual frágil — falta o workflow `release.yml` (tag → CI → build → push gem) e o `CHANGELOG.md`.
5. **Confiar** que a publicação é segura — falta RubyGems trusted publishing (OIDC), gem assinado/checksummed e versão com fonte única de verdade.
6. **Pedir ajuda à IA** com código correto — falta a skill `skills/nfeio-ruby-sdk/SKILL.md`, espelhada na skill do Node.

A política de release é conservadora porque o SDK toca **emissão fiscal** (bug = nota fiscal errada = problema legal): a primeira tag estável `v1.0.0` é precedida de pelo menos um `v1.0.0-rc.1` e um período de pré-lançamento mínimo antes do GA.

Esta change não adiciona superfície de SDK — é **release engineering + documentação + skill de IA**. Depende de todas as changes irmãs estarem aplicadas e estáveis.

## What Changes

### Gemspec moderno + fonte única da versão

- Reescrever `nfe-io.gemspec`: nome `nfe-io` (mantido), `required_ruby_version >= 3.2`, **sem `add_dependency`** (zero runtime deps), `add_development_dependency` para rspec/rubocop/steep/simplecov, metadados completos (`homepage`, `source_code_uri`, `changelog_uri`, `bug_tracker_uri`, `documentation_uri`, `rubygems_mfa_required => "true"`), `spec.files` via `git ls-files` excluindo `spec/`, `samples/`, `skills/`.
- `Nfe::VERSION` em `lib/nfe/version.rb` é a **fonte única de verdade**; o gemspec e o workflow leem dela. Subir de `0.3.2` para `1.0.0`.
- `spec.metadata["rubygems_mfa_required"] = "true"` e empacotar `*.rbs` em `sig/` no gem.

### CHANGELOG.md (pt-BR, Keep a Changelog)

- Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) + [SemVer](https://semver.org/lang/pt-BR/).
- Seção `[Não lançado]` no topo + entrada `[1.0.0] - AAAA-MM-DD` com a reescrita greenfield categorizada (`Adicionado`, `Alterado`, `Removido`, `Corrigido`).
- O `release.sh` rotaciona `[Não lançado]` → `[X.Y.Z]` na data do release.

### MIGRATION.md exaustivo (pt-BR) v0.3.x → v1.0.0

- Tabela de instalação (`gem "nfe-io", "~> 0.3"` → `~> 1.0`).
- Requisito de Ruby (2.x → 3.2+).
- Configuração: global `Nfe.api_key("...")` (setter por método) e `Nfe.configure { |c| c.url = ... }` → `Nfe::Client.new(api_key:)` (instância, não estático) + roteamento multi-host automático + segunda chave `data_api_key:` + fallback de env vars (`NFE_API_KEY`/`NFE_DATA_API_KEY`, argumento explícito vence).
- Mapeamento de classes v0.3.x → recursos v1 (todos os 17 accessors snake_case).
- Mapeamento método-a-método por recurso (assinatura antiga → nova).
- `rest-client` removido — exceptions de rede agora são `Nfe::ApiConnectionError`/`Nfe::TimeoutError` (`TimeoutError < ApiConnectionError`) em vez de `RestClient::Exception`.
- Nova hierarquia de erros tipados (tabela completa `Nfe::Error` e subclasses por status HTTP).
- Contrato 202 discriminado (`Pending`/`Issued`) + polling manual via `FlowStatus`.
- Verificação de assinatura de webhook (`X-Hub-Signature` + HMAC-SHA1 sobre bytes crus).
- Downloads agora retornam `String` binária (`ASCII-8BIT`).
- Lista de recursos diferidos no v1.0 (`create_and_wait`, `create_batch`, upload de certificado multipart).
- Apêndices end-to-end: **script vanilla**, **Rails initializer**, e referência a integradores.

### README.md expandido (pt-BR)

- Badges (RubyGems version, CI, cobertura, licença), instalação, requisitos (Ruby 3.2+, zero deps).
- Quickstart `Nfe::Client.new(api_key:)`.
- Mapa de recursos: tabela dos 17 accessors → host → operações-chave (espelha a skill).
- 1-liner por recurso.
- Tratamento de erros, polling do contrato 202, configuração (timeout, retry, `data_api_key`), downloads binários, verificação de webhook.
- Seção "Versionamento" (semver + cadência RC) e link para `MIGRATION.md`.

### CONTRIBUTING.md (pt-BR)

- Política de branches: `master` (v1) ativo, `0.x-legacy` congelado.
- Setup local (Ruby 3.2, `bundle install`), toolchain (`rake spec`, `rubocop`, `steep check`, `rake generate:check`).
- Convenções: `# frozen_string_literal: true` em todo `.rb`, nunca editar `lib/nfe/generated/`, regenerar de OpenAPI.
- Workflow OpenSpec, commits semânticos, cadência de release (RC + período de beta).

### samples/ runnable

Um script Ruby executável por caso de uso primário (`ruby samples/<arquivo>.rb`), carregando `samples/config.rb` (lê env vars), com `samples/.env.example`, `samples/README.md` e `.env` no `.gitignore`.

### .github/workflows/release.yml + scripts/release.sh

- `release.yml` disparado por push de tag `v*`: roda **todo o CI** (rspec + rubocop + steep + `generate:check`) na matrix Ruby 3.2/3.3/3.4, depois `gem build`, **publica no RubyGems via trusted publishing (OIDC)**, anexa o `.gem` + checksum SHA-256 ao GitHub Release.
- `scripts/release.sh` interativo (`--dry-run`, `--skip-tests`, `--skip-git`): valida branch/working tree/CI, pede versão, atualiza `Nfe::VERSION`, rotaciona CHANGELOG, commit, tag anotada, push.

### skills/nfeio-ruby-sdk/SKILL.md + references/

- Skill de IA modelada na `nfeio-node-sdk`: front-matter com gatilhos, quickstart, mapa de recursos, padrões (contrato 202, erros, paginação, downloads, webhook), pitfalls idiomáticos de Ruby, decision tree, e arquivos `references/*.md` segmentados.

### Integração com nfeio-docs

- **Atualizar** a página viva existente `docs/desenvolvedores/bibliotecas/ruby.md` no `nfeio-docs` (repo é a fonte de verdade): remover o snippet errado de webhook (`X-NFEIO-Signature` + Base64) e os exemplos `Nfe.api_key` v0.3, adicionar o quickstart `Nfe::Client.new(api_key:)` e espelhar a estrutura das docs do Node (`migracao`/`changelog`/`exemplos`), com link para README/MIGRATION. Tarefa coordenada com o time de docs.

## Capabilities

### New Capabilities
- `release-tooling`: gemspec + versão fonte-única, CHANGELOG, MIGRATION, README, CONTRIBUTING, samples, workflow de release (CI gate + RubyGems OIDC + gem assinado/checksummed), `release.sh`, skill `nfeio-ruby-sdk` e integração de docs.

### Modified Capabilities
- Nenhuma. Esta change apenas **introduz** `release-tooling`; as capabilities funcionais permanecem como definidas pelas changes irmãs. (O banner de status no README é cosmético e coberto aqui, sem alterar requirements de outra capability.)

## Impact

- **Affected code/files**: `nfe-io.gemspec`, `lib/nfe/version.rb`, `CHANGELOG.md`, `MIGRATION.md`, `README.md`, `CONTRIBUTING.md`, `samples/*`, `scripts/release.sh`, `.github/workflows/release.yml`, `skills/nfeio-ruby-sdk/*`, `.gitignore`.
- **Spec impact**: cria a capability `release-tooling`.
- **Dependencies**: depende de `add-ruby-foundation`, `add-http-transport`, `add-openapi-pipeline`, `add-client-core`, `add-entity-resources`, `add-invoice-resources`, `add-rtc-invoice-emission` e `add-lookup-resources` — todas aplicadas e estáveis. Esta é a última change da v1.
- **Riscos**:
  - Trusted publishing (OIDC) precisa de configuração one-time no RubyGems vinculando o repo GitHub; fallback documentado é `gem push` com API key em secret.
  - Publicação no RubyGems é irreversível por versão (yank ≠ delete); mitigado por RC + beta antes do GA.
  - `MIGRATION.md` completo é longo de manter; aceito como referência canônica versionada por tag.
- **Política de release**: a primeira tag estável `v1.0.0` SHALL ser precedida de pelo menos um RC e um período de beta. Capturado como requirement no spec.
