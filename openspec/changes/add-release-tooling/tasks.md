# Tasks — add-release-tooling

> Greenfield: todas as caixas começam desmarcadas. Depende de todas as changes
> irmãs (`add-ruby-foundation` … `add-lookup-resources`) aplicadas e estáveis.

## 1. Gemspec moderno + fonte única da versão

- [ ] 1.1 Reescrever `nfe-io.gemspec`: remover `# coding: utf-8`, remover `$LOAD_PATH` hack legado, `require_relative "lib/nfe/version"`.
- [ ] 1.2 `spec.name = "nfe-io"` (mantido); `spec.version = Nfe::VERSION`.
- [ ] 1.3 Atualizar metadados: `spec.authors`, `spec.email = ["suporte@nfe.io"]`, `spec.summary`/`spec.description` (SDK oficial NFE.io para documentos fiscais brasileiros), `spec.homepage = "https://nfe.io"`, `spec.license = "MIT"`.
- [ ] 1.4 `spec.required_ruby_version = ">= 3.2"`.
- [ ] 1.5 **Remover** `spec.add_dependency "rest-client"` e qualquer outra dependência de runtime (zero deps; apenas stdlib).
- [ ] 1.6 `add_development_dependency`: `rspec`, `rubocop`, `rubocop-rspec`, `steep`, `rbs`, `simplecov`, `rake`. Remover `bundler`/`byebug` legados (ou manter `debug` da stdlib).
- [ ] 1.7 `spec.metadata`: `"homepage_uri"`, `"source_code_uri" => "https://github.com/nfe/client-ruby"`, `"changelog_uri" => ".../blob/master/CHANGELOG.md"`, `"bug_tracker_uri"`, `"documentation_uri"`, `"rubygems_mfa_required" => "true"`.
- [ ] 1.8 `spec.files = Dir.chdir(__dir__) { \`git ls-files -z\`.split("\x0") }` rejeitando `spec/`, `samples/`, `skills/`, `.github/`, `openspec/`, dotfiles de dev — mas **incluindo** `sig/**/*.rbs`, `lib/**/*.rb`, `README.md`, `CHANGELOG.md`, `MIGRATION.md`, `LICENSE.txt`.
- [ ] 1.9 `spec.require_paths = ["lib"]`; confirmar que `sig/` é empacotado (RBS distribuído junto ao gem).
- [ ] 1.10 Atualizar `lib/nfe/version.rb` para `Nfe::VERSION = "1.0.0"` (com `# frozen_string_literal: true` no topo) — fonte única lida por gemspec e workflow.
- [ ] 1.11 `bundle exec rake build` gera `nfe-io-1.0.0.gem` sem warnings; `gem spec nfe-io-1.0.0.gem` mostra metadados corretos e zero runtime deps.
- [ ] 1.12 Atualizar `Rakefile` para expor `build`, `install`, `release` (Bundler::GemHelper) além de `spec`.

## 2. CHANGELOG.md (pt-BR, Keep a Changelog)

- [ ] 2.1 Criar `CHANGELOG.md` com cabeçalho Keep a Changelog 1.1.0 + SemVer (links pt-BR).
- [ ] 2.2 Seção `## [Não lançado]` vazia no topo (rotacionada pelo `release.sh`).
- [ ] 2.3 Entrada `## [1.0.0] - AAAA-MM-DD` documentando a reescrita greenfield, categorizada:
  - `### Adicionado`: `Nfe::Client.new(api_key:)`, 17 recursos snake_case, modelos `Data.define` gerados, RBS + Steep, contrato 202 discriminado, emissão RTC (IBS/CBS/IS), verificação de webhook HMAC-SHA1, roteamento multi-host, retry/backoff, downloads binários.
  - `### Alterado`: namespace `Nfe`, Ruby floor 3.2, paginação page/cursor.
  - `### Removido`: dependência `rest-client`, config global `Nfe.api_key`, classes achatadas v0.3.x.
- [ ] 2.4 Rodapé com links de comparação de versões (`[1.0.0]: .../releases/tag/v1.0.0`, `[Não lançado]: .../compare/v1.0.0...HEAD`).

## 3. MIGRATION.md exaustivo (pt-BR) v0.3.x → v1.0.0

- [ ] 3.1 Cabeçalho explicando que v1 é reescrita completa sem camada de compatibilidade; `master` = v1, branch `0.x-legacy` congelada.
- [ ] 3.2 Seção "Instalação": `gem "nfe-io", "~> 0.3"` → `gem "nfe-io", "~> 1.0"`; aviso de breaking change major.
- [ ] 3.3 Seção "Versão do Ruby": Ruby 2.x → 3.2/3.3/3.4.
- [ ] 3.4 Seção "Configuração": `Nfe.api_key("...")` (setter global por **chamada de método**, não atribuição) → `Nfe::Client.new(api_key: "...")` (instância). Documentar também `Nfe.configure { |c| c.url = "..." }` → `Nfe::Client.new(base_url:)` e o padrão por-classe `Nfe::ServiceInvoice.company_id("...")` → `client.service_invoices.create(company_id:, ...)` (o company_id deixa de ser estado global por classe e passa a ser argumento por chamada). Documentar que a base URL deixou de ser global e passa a ser roteada por recurso (api.nfe.io, api.nfse.io, address.api.nfe.io/v2, nfe.api.nfe.io, legalentity.api.nfe.io, naturalperson.api.nfe.io).
- [ ] 3.5 Seção "Segunda chave de API" (novidade): `data_api_key:` para recursos de dados (CEP/CNPJ/CPF/query), com fallback para `api_key`.
- [ ] 3.6 Seção "Mapeamento de classes" — tabela classes v0.3.x → accessor v1 (os 17: `service_invoices`, `product_invoices`, `consumer_invoices`, `transportation_invoices`, `inbound_product_invoices`, `product_invoice_query`, `consumer_invoice_query`, `companies`, `legal_people`, `natural_people`, `webhooks`, `addresses`, `legal_entity_lookup`, `natural_person_lookup`, `tax_calculation`, `tax_codes`, `state_taxes`).
- [ ] 3.7 Seção "Mapeamento de métodos por recurso" — para cada recurso, tabela método v0.3.x → método v1 (snake_case, com diff de assinatura).
- [ ] 3.8 Seção "Remoção do rest-client" — `RestClient::Exception` → hierarquia `Nfe::ApiConnectionError`/`Nfe::TimeoutError` (`TimeoutError < ApiConnectionError`); nenhuma dependência de runtime.
- [ ] 3.9 Seção "Tratamento de erros" — tabela completa `Nfe::Error` base + `AuthenticationError`(401), `AuthorizationError`(403), `InvalidRequestError`(400/422), `NotFoundError`(404), `ConflictError`(409), `RateLimitError`(429), `ServerError`(5xx), `ApiConnectionError`, `TimeoutError`(< `ApiConnectionError`), `SignatureVerificationError`, `ConfigurationError`, `InvoiceProcessingError`.
- [ ] 3.10 Seção "Respostas assíncronas (202)" — contrato discriminado `Pending`/`Issued`; exemplo de loop de polling manual usando `Nfe::FlowStatus.terminal?`.
- [ ] 3.11 Seção "Verificação de assinatura de webhook" — `X-Hub-Signature` + HMAC-SHA1 sobre **bytes crus** do corpo (não JSON re-serializado); ler `request.body.read` antes de parsear; comparar case-insensitive; usar `OpenSSL::HMAC` + comparação timing-safe (`Rack::Utils.secure_compare` ou implementação própria com stdlib). Alertar que docs antigas de distribuição (`X-NFe-Signature` + SHA-256) estão **erradas**.
- [ ] 3.12 Seção "Downloads" — agora retornam `String` binária (`ASCII-8BIT`) em vez de objeto rest-client; salvar com `File.binwrite`.
- [ ] 3.13 Seção "Features diferidas na v1.0" — `create_and_wait`, `create_batch`, upload/replace/validate de certificado multipart, `getStatus` como endpoint HTTP dedicado (derivado de `retrieve` no v1). Explicar workaround (polling manual via `FlowStatus`).
- [ ] 3.14 Apêndice A — exemplo end-to-end **vanilla** (script CLI v0.3.x → v1, diff lado a lado: emissão de NFS-e + polling).
- [ ] 3.15 Apêndice B — exemplo end-to-end **Rails** (initializer `config/initializers/nfe.rb` com `Nfe::Client` memoizado; controller de webhook validando assinatura sobre `request.raw_post`).
- [ ] 3.16 Seção "Resumo de breaking changes" — bullet list categorizada (gem, Ruby, configuração, superfície de API, erros, downloads, webhook).
- [ ] 3.17 Revisão de ponta a ponta: nenhum método/campo inventado; nomes batem com as specs das changes irmãs.

## 4. README.md expandido (pt-BR)

- [ ] 4.1 Substituir o README legado; H1 + tagline + badges (RubyGems version, CI status, cobertura, licença MIT).
- [ ] 4.2 Seção "Requisitos": Ruby 3.2+, zero dependências de runtime (apenas stdlib: net/http, json, openssl, uri, securerandom, stringio, time, base64).
- [ ] 4.3 Seção "Instalação": `gem install nfe-io` e `bundle add nfe-io`.
- [ ] 4.4 Seção "Quickstart": `require "nfe"`, `Nfe::Client.new(api_key: ENV["NFE_API_KEY"])`, exemplo curto de emissão + leitura.
- [ ] 4.5 Seção "Configuração": `api_key:`, `data_api_key:`, `environment:`, `timeout:`, `retry:` (max_retries/base_delay/max_delay/backoff), com defaults. Documentar fallback de variáveis de ambiente: `Configuration` lê `NFE_API_KEY` / `NFE_DATA_API_KEY` do ambiente quando o argumento explícito é omitido (precedência: argumento explícito vence o env).
- [ ] 4.5a Seção "Sandbox vs Produção": o parâmetro `environment:` do `Nfe::Client.new` é um **símbolo** que seleciona uma CHAVE (credencial/conta), **não** uma URL — o roteamento de host continua automático por recurso. Explicar como obter credenciais de teste. Alertar que `product_invoices`/`consumer_invoices` recebem um parâmetro `environment` **String** SEPARADO (`"Production"`/`"Test"`) nas operações de `list`/emissão. Incluir um exemplo de emissão em ambiente de teste.
- [ ] 4.6 Seção "Mapa de recursos": tabela dos 17 accessors → host → escopo (company/global) → operações-chave (espelha a skill).
- [ ] 4.7 Seção "Recursos (1-liner cada)": um exemplo por recurso (service_invoices, product_invoices, consumer_invoices, transportation_invoices, inbound_product_invoices, companies, legal_people, natural_people, webhooks, addresses, legal_entity_lookup, natural_person_lookup, tax_calculation, tax_codes, state_taxes, product_invoice_query, consumer_invoice_query).
- [ ] 4.8 Seção "Emissão assíncrona (contrato 202)": discriminar `Pending`/`Issued`; loop de polling manual via `Nfe::FlowStatus.terminal?`.
- [ ] 4.9 Seção "Tratamento de erros": `begin/rescue` por classe tipada; tabela de erros.
- [ ] 4.10 Seção "Downloads": retornam `String` binária; `File.binwrite`.
- [ ] 4.11 Seção "Webhooks": criar webhook + validar assinatura HMAC-SHA1 sobre bytes crus. Alertar que validade de assinatura **não** é prova de frescor (a NFE.io não envia primitiva anti-replay/timestamp): handlers DEVEM ser idempotentes e deduplicar pelo id do evento/nota.
- [ ] 4.12 Seção "Versionamento": semver + cadência RC/beta + link para `CHANGELOG.md` e `MIGRATION.md`.
- [ ] 4.13 Seção "Type checking": SDK distribui `.rbs` em `sig/`; instruções de Steep para consumidores.
- [ ] 4.14 Remover o badge/banner Travis legado (`.travis.yml`) e qualquer referência a `pluga.co`.

## 5. CONTRIBUTING.md (pt-BR)

- [ ] 5.1 Seção "Branches": `master` (v1, ativo) e `0.x-legacy` (congelada, sem manutenção); PRs contra `0.x-legacy` são fechados.
- [ ] 5.2 Seção "Setup local": Ruby 3.2+ (via rbenv/asdf), `bundle install`.
- [ ] 5.3 Seção "Toolchain" — tabela: `rake spec` (RSpec), `rubocop` (lint), `steep check` (type check), `rake generate` / `rake generate:check` (codegen OpenAPI), `simplecov` (cobertura ≥ 80%).
- [ ] 5.4 Seção "Convenções": `# frozen_string_literal: true` no topo de todo `.rb`; PSR-equivalente snake_case; keyword args; `Data.define` para value objects.
- [ ] 5.5 Seção "Arquivos gerados": nunca editar `lib/nfe/generated/` nem `sig/` gerados à mão; regenerar de `openapi/*.yaml` via `rake generate`; commitar spec + gerado no mesmo PR; CI falha via `generate:check` se fora de sync.
- [ ] 5.6 Seção "Commits": Conventional Commits (`feat:`, `fix:`, `docs:`, `chore(release):`).
- [ ] 5.7 Seção "Workflow OpenSpec": changes ativas em `openspec/changes/`.
- [ ] 5.8 Seção "Cadência de release": patch direto após CI verde; minor/major com RC + período de beta (ver `release-tooling`).

## 6. samples/ runnable

- [ ] 6.1 Criar `samples/.env.example` com `NFE_API_KEY=`, `NFE_DATA_API_KEY=`, `NFE_COMPANY_ID=`, `NFE_WEBHOOK_SECRET=`.
- [ ] 6.2 Criar `samples/config.rb` — bootstrap: `require "nfe"`, lê env vars, instancia `$nfe = Nfe::Client.new(api_key:, data_api_key:)` e expõe `$company_id`; aborta com mensagem clara se `NFE_API_KEY` ausente.
- [ ] 6.3 Criar `samples/README.md` — instruções: copiar `.env.example`, exportar variáveis, `ruby samples/<arquivo>.rb`.
- [ ] 6.4 `samples/service_invoice_issue.rb` — emissão NFS-e + polling manual + `download_pdf` salvando com `File.binwrite`.
- [ ] 6.5 `samples/product_invoice_issue.rb` — emissão NF-e (assíncrona, conclusão via webhook).
- [ ] 6.6 `samples/consumer_invoice_issue.rb` — emissão NFC-e (contrato discriminado).
- [ ] 6.7 `samples/company_crud.rb` — create + list + retrieve + update + remove.
- [ ] 6.8 `samples/legal_person_create.rb` e `samples/legal_person_update.rb`.
- [ ] 6.9 `samples/webhook_verify.rb` — mini servidor (`WEBrick`/`rackup` da stdlib ou exemplo de handler) que lê bytes crus, valida HMAC-SHA1 e loga.
- [ ] 6.10 `samples/cnpj_lookup.rb` — `legal_entity_lookup.basic_info` + `state_tax_for_invoice`.
- [ ] 6.11 `samples/cpf_lookup.rb` — `natural_person_lookup.status`.
- [ ] 6.12 `samples/cep_lookup.rb` — `addresses.lookup_by_postal_code("01310-100")`.
- [ ] 6.13 `samples/tax_calculation.rb` — `tax_calculation.calculate(tenant_id, request)`.
- [ ] 6.14 `samples/rtc_service_invoice.rb` — emissão NFS-e RTC com grupo `ibs_cbs` (depende de `add-rtc-invoice-emission`).
- [ ] 6.15 Cada sample com comentário-cabeçalho de pré-requisitos (env vars, company sandbox).
- [ ] 6.16 Adicionar `samples/.env` ao `.gitignore` (não commitar credenciais).

## 7. scripts/release.sh

- [ ] 7.1 Criar `scripts/release.sh` (bash, `set -euo pipefail`, cores, `--help`).
- [ ] 7.2 Flags: `--dry-run`, `--skip-tests`, `--skip-git`.
- [ ] 7.3 Pre-flight: branch é `master`? working tree limpo? CI verde no último commit (`gh run list --branch master --limit 1 --json conclusion`)? `ruby`/`bundle`/`gh` disponíveis?
- [ ] 7.4 Prompt interativo de versão; validar regex `^\d+\.\d+\.\d+(-(rc|beta)\.\d+)?$`; rejeitar inválido.
- [ ] 7.5 Falhar cedo se a tag `vX.Y.Z` já existir (idempotência).
- [ ] 7.6 Atualizar `lib/nfe/version.rb` (`Nfe::VERSION`) com a forma **pontilhada** do prerelease: tag `vX.Y.Z-rc.N` (hífen) mas `Nfe::VERSION = "X.Y.Z.rc.N"` (ponto — exigido pelo RubyGems). Para release final, ambos são `X.Y.Z`. A tag git usa a forma com hífen; `version.rb` e o gem publicado usam a forma pontilhada.
- [ ] 7.7 Rotacionar `CHANGELOG.md`: `[Não lançado]` → `[X.Y.Z] - $(date +%F)`.
- [ ] 7.8 Rodar `bundle exec rake spec`, `rubocop`, `steep check`, `rake generate:check` (a menos que `--skip-tests`).
- [ ] 7.9 Commit `chore(release): vX.Y.Z` (a menos que `--skip-git`/`--dry-run`).
- [ ] 7.10 Tag anotada `vX.Y.Z` com mensagem extraída do CHANGELOG.
- [ ] 7.11 Push commit + tag para `origin` (a menos que `--skip-git`/`--dry-run`).
- [ ] 7.12 `--dry-run` imprime cada passo sem efeitos colaterais.
- [ ] 7.13 NÃO faz `gem push` localmente — a publicação no RubyGems acontece no workflow via OIDC após o push da tag.

## 8. .github/workflows/release.yml (CI gate + RubyGems OIDC)

- [ ] 8.1 Criar `.github/workflows/release.yml`; trigger `push: tags: ['v*']`.
- [ ] 8.2 Job `verify`: matrix Ruby `['3.2','3.3','3.4']`; `bundle install`; `bundle exec rake spec` (com SimpleCov, falha < 80%), `bundle exec rubocop`, `bundle exec steep check`, `bundle exec rake generate:check`. Falha aqui = release abortado.
- [ ] 8.3 Job `publish`: `needs: verify`; roda em Ruby 3.3; `permissions: { contents: write, id-token: write }`.
- [ ] 8.4 `publish`: `gem build nfe-io.gemspec`; gerar checksum `sha256sum nfe-io-*.gem > nfe-io-*.gem.sha256`.
- [ ] 8.5 `publish`: **RubyGems trusted publishing via OIDC** (`rubygems/configure-rubygems-credentials` + `gem push`), sem API key em secret quando OIDC estiver configurado.
- [ ] 8.5a `publish`: passo de **asserção de versão** — derivar a versão pontilhada da tag (`vX.Y.Z-rc.N` → `X.Y.Z.rc.N`) e afirmar que a versão do gem construído (`Nfe::VERSION`) é exatamente igual; abortar o publish em caso de divergência.
- [ ] 8.6 `publish`: criar GitHub Release (`gh release create` ou `softprops/action-gh-release`) com notas extraídas do CHANGELOG e anexar o `.gem` + `.sha256`.
- [ ] 8.7 Pré-releases (tags `*-rc.*`/`*-beta.*`) marcadas como prerelease no GitHub Release e empurradas com `--otp`/pre-release no RubyGems (não viram `latest`).
- [ ] 8.8 Fallback documentado: se OIDC não estiver disponível, usar `GEM_HOST_API_KEY` de secret (`RUBYGEMS_API_KEY`).
- [ ] 8.9 Confirmar que o CI base (`.github/workflows/ci.yml`, de `add-ruby-foundation`) cobre push/PR em `master`; o `release.yml` reusa os mesmos comandos para o gate.

## 9. skills/nfeio-ruby-sdk/ (skill de IA)

- [ ] 9.1 Criar `skills/nfeio-ruby-sdk/SKILL.md` com front-matter YAML (`name: nfeio-ruby-sdk`, `description:` com gatilhos: import de `nfe`/`Nfe::Client`, NFE.io, NFS-e/NF-e/CT-e/NFC-e, nota fiscal, CNPJ/CPF/CEP, etc., explicitando que cobre os 17 recursos).
- [ ] 9.2 Seção "Gem & require": `gem "nfe-io"`, `require "nfe"`, Ruby 3.2+, zero deps.
- [ ] 9.3 Seção "Quickstart": `Nfe::Client.new(api_key:, data_api_key:, environment:, timeout:, retry:)`; documentar fallback de env vars `NFE_API_KEY`/`NFE_DATA_API_KEY` (argumento explícito vence) e que `environment:` é um símbolo que seleciona uma CHAVE, não uma URL.
- [ ] 9.3a Seção "Sandbox vs Produção": como obter credenciais de teste; `product_invoices`/`consumer_invoices` recebem um parâmetro `environment` String SEPARADO (`"Production"`/`"Test"`) em list/emissão; exemplo de emissão em Test.
- [ ] 9.4 Seção "Resource Map": tabela dos 17 accessors snake_case → host → escopo → operações.
- [ ] 9.5 Seção "Contrato 202": discriminar `Pending`/`Issued`; polling manual com `Nfe::FlowStatus.terminal?`; estados terminais e não-terminais.
- [ ] 9.6 Seção "Error handling": hierarquia `Nfe::Error` + subclasses por status; `rescue` idiomático.
- [ ] 9.7 Seção "Pagination": page-style (`page_index`/`page_count`) vs cursor (`starting_after`/`ending_before`/`limit`); `environment` obrigatório em product_invoices.
- [ ] 9.8 Seção "Downloads": `String` binária (`ASCII-8BIT`); exceção: `product_invoices.download_pdf` retorna recurso com URI; `File.binwrite`.
- [ ] 9.9 Seção "Webhooks": `X-Hub-Signature` + HMAC-SHA1 sobre bytes crus (`request.raw_post`/`request.body.read`), comparação timing-safe. Alertar que validade != frescor (sem primitiva anti-replay): handlers idempotentes e dedupe por id do evento/nota.
- [ ] 9.10 Seção "Pitfalls idiomáticos Ruby": `companies.delete` chamado `remove` (evitar conflito), keyword args, value objects imutáveis `Data.define`, access keys de 44 dígitos, carta de correção 15–1000 chars sem acentos.
- [ ] 9.11 Seção "Decision tree" ("Quero…" → recurso.método).
- [ ] 9.12 Criar `skills/nfeio-ruby-sdk/references/service-invoices-and-polling.md`.
- [ ] 9.13 Criar `skills/nfeio-ruby-sdk/references/product-invoices-and-taxes.md`.
- [ ] 9.14 Criar `skills/nfeio-ruby-sdk/references/data-services-and-lookups.md`.
- [ ] 9.15 Criar `skills/nfeio-ruby-sdk/references/error-handling-and-patterns.md`.
- [ ] 9.16 Criar `skills/nfeio-ruby-sdk/references/rtc-emission.md` (IBS/CBS/IS; depende de `add-rtc-invoice-emission`).

## 10. Integração com nfeio-docs

- [ ] 10.1 **Atualizar** (não criar) a página viva existente `docs/desenvolvedores/bibliotecas/ruby.md` no `nfeio-docs` (repo é a fonte de verdade), coordenando com o time de docs.
- [ ] 10.2 **Remover** o snippet errado de webhook (`X-NFEIO-Signature` + Base64) e os exemplos de `Nfe.api_key` globais do estilo v0.3.
- [ ] 10.3 **Adicionar** o quickstart `Nfe::Client.new(api_key:)` e espelhar a estrutura das docs do Node (seções `migracao`/`changelog`/`exemplos`): instalação, quickstart, link para README e MIGRATION no GitHub.
- [ ] 10.4 Linkar a página de docs de volta no README (seção "Documentação").

## 11. Validação final

- [ ] 11.1 `bundle exec rake spec` com SimpleCov — cobertura ≥ 80% em `lib/nfe/` excluindo `lib/nfe/generated/`.
- [ ] 11.2 `bundle exec rubocop` — sem offenses.
- [ ] 11.3 `bundle exec steep check` — sem erros de tipo.
- [ ] 11.4 `bundle exec rake generate:check` — gerado em sync com `openapi/*.yaml`.
- [ ] 11.5 `gem build nfe-io.gemspec` — gera `nfe-io-1.0.0.gem` sem warnings; `gem spec` confirma zero runtime deps e `sig/` empacotado.
- [ ] 11.6 Rodar todos os samples contra sandbox — compilam e rodam sem erro.
- [ ] 11.7 `./scripts/release.sh --dry-run` — imprime os passos sem efeitos colaterais.
- [ ] 11.8 `openspec validate add-release-tooling` — passa.
- [ ] 11.9 Revisão manual do `MIGRATION.md` e `README.md` de ponta a ponta.

## 12. Política de RC + beta e GA

- [ ] 12.1 Cortar `v1.0.0-rc.1` via `scripts/release.sh`; confirmar que o workflow publica como prerelease no RubyGems e no GitHub.
- [ ] 12.2 Anunciar o RC internamente (Teams) + para integradores conhecidos; abrir issue "v1.0 Beta Tracking".
- [ ] 12.3 Período de beta (mínimo definido na política); coletar feedback.
- [ ] 12.4 Sem issues críticas → cortar `v1.0.0` GA; com issue crítica → `v1.0.0-rc.2`, reinicia o relógio.
- [ ] 12.5 Pós-GA: atualizar badges do README para estável; confirmar `gem install nfe-io` resolve para `1.0.0` como `latest`.
- [ ] 12.6 No GA, **remover** o banner "v1 em desenvolvimento" do README — amarrado ao fluxo prerelease-vs-final do `release.sh` (prerelease mantém o banner; release final o remove). Adicionar uma nota de forward-compat de uma linha de que `Pending`/`Issued` + `FlowStatus` são API pública estável.
