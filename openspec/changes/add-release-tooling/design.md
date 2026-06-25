# Design — add-release-tooling

## Context

Esta é a **última change da v1.0.0** do gem `nfe-io`. As changes irmãs já entregaram:

- `add-ruby-foundation` — estrutura do gem, `# frozen_string_literal: true`, RuboCop, RSpec, SimpleCov, CI matrix Ruby 3.2/3.3/3.4, branch `master` (v1) e `0.x-legacy` (congelada).
- `add-http-transport` — `Net::HTTP` puro, retry/backoff, timeouts, downloads binários.
- `add-openapi-pipeline` — gerador OpenAPI → `Data.define` em `lib/nfe/generated/` + `.rbs` em `sig/`.
- `add-client-core` — `Nfe::Client.new(api_key:)`, accessors lazy, roteamento multi-host, hierarquia de erros, contrato 202 `Pending`/`Issued`, `FlowStatus`.
- `add-entity-resources`, `add-invoice-resources`, `add-rtc-invoice-emission`, `add-lookup-resources` — os 17 recursos.

O que falta é **release engineering + documentação + skill de IA**. Nenhuma linha de runtime nova; o trabalho é tornar o SDK **instalável, migrável, avaliável, publicável e assistível por IA**.

A peça de maior valor para o usuário final é o `MIGRATION.md` (separa "SDK pronto" de "SDK adotável"). Para o mantenedor é o par `release.sh` + `release.yml` (transforma o ritual frágil de release num único comando + gate de CI). Para integradores assistidos por IA é a skill `nfeio-ruby-sdk`.

O `nfe-io.gemspec` legado ainda declara `rest-client`, Ruby 2.4.1 e metadados de 2017 — precisa de reescrita total, batendo com a decisão canônica de zero dependências de runtime.

## Goals / Non-Goals

**Goals**
- `nfe-io.gemspec` moderno: Ruby ≥ 3.2, **zero runtime deps**, metadados completos, MFA obrigatória, `sig/` empacotado, versão fonte-única em `Nfe::VERSION`.
- `CHANGELOG.md` (pt-BR, Keep a Changelog) e `MIGRATION.md` exaustivo v0.3.x → v1.0.0 cobrindo 100% dos recursos.
- `README.md` expandido + `CONTRIBUTING.md` (pt-BR).
- `samples/` com um script runnable por caso de uso primário.
- `scripts/release.sh` single-command com `--dry-run`.
- `.github/workflows/release.yml`: tag → CI completo (rspec + rubocop + steep + generate:check) → `gem build` → publicação no RubyGems via **trusted publishing (OIDC)** → GitHub Release com `.gem` + checksum SHA-256.
- Skill de IA `skills/nfeio-ruby-sdk/SKILL.md` + `references/`, modelada na do Node.
- Política RC + beta antes de qualquer GA.
- Atualizar a página viva existente `docs/desenvolvedores/bibliotecas/ruby.md` no `nfeio-docs` (remover snippet de webhook errado e exemplos `Nfe.api_key` v0.3; adicionar quickstart `Nfe::Client.new`; espelhar a estrutura das docs do Node).

**Non-Goals**
- Benchmarks de performance (SDK é síncrono/blocking; sem base comparável útil).
- Telemetria/usage stats (privacidade; Stripe não tem; pular).
- Site de docs próprio (`nfeio-docs` é mantido pelo time; o SDK apenas linka).
- Tradução EN do MIGRATION na v1.0 (audiência primária é pt-BR, NF-e/NFS-e/NFC-e/CT-e são instrumentos fiscais brasileiros).
- Ferramenta de auto-upgrade (transform/rewriter v0.3.x → v1) — futuro se houver demanda.
- Novos recursos de SDK — fora de escopo desta change.

## Decisions

### D1. Zero dependências de runtime — gemspec sem `add_dependency`
**Decisão**: o `nfe-io.gemspec` v1 **não** declara nenhuma dependência de runtime; apenas `add_development_dependency` (rspec, rubocop, steep, rbs, simplecov, rake). `required_ruby_version >= 3.2`.

**Por quê**: decisão canônica do projeto (apenas stdlib: `net/http`, `json`, `openssl`, `uri`, `securerandom`, `stringio`, `time`, `base64`). O legado dependia de `rest-client ~> 2.0.2`; removê-lo elimina cadeia transitiva e conflitos de versão no consumidor — vantagem competitiva igual à do SDK Node (zero deps).

### D2. Versão como fonte única em `Nfe::VERSION`
**Decisão**: `lib/nfe/version.rb` é a única fonte da verdade. O gemspec faz `require_relative "lib/nfe/version"` e usa `Nfe::VERSION`; o `release.sh` reescreve essa constante; o `release.yml` lê a tag.

**Por quê**: evita drift entre gemspec, tag git e RubyGems. Padrão idiomático Ruby (Bundler `gem` scaffold). Bump `0.3.2 → 1.0.0`.

**Forma hífen vs ponto**: as tags git usam a forma com hífen (`vX.Y.Z`, `vX.Y.Z-rc.N`), mas `Nfe::VERSION` e o gem publicado usam a forma **pontilhada** (`X.Y.Z`, `X.Y.Z.rc.N`) — o RubyGems exige o ponto no prerelease. O `release.sh` escreve a forma pontilhada em `version.rb` e cria a tag com hífen; o `release.yml` deriva a versão pontilhada da tag e afirma que o gem construído bate (aborta em divergência). O cenário de Bundler/`~> 1.0` usa a forma pontilhada (`= 1.0.0.rc.1`) — mantido.

### D3. Publicação via RubyGems trusted publishing (OIDC), não API key em secret
**Decisão**: o job `publish` do `release.yml` usa `permissions: id-token: write` + trusted publishing do RubyGems (token OIDC efêmero), sem `GEM_HOST_API_KEY` persistente. Fallback documentado: secret `RUBYGEMS_API_KEY` se OIDC não estiver configurado para o repo.

**Por quê**: OIDC elimina credencial de longa duração no GitHub (superfície de ataque menor), espelha o estado-da-arte de supply-chain security e o trusted publishing do PyPI/npm. A vinculação repo↔gem é configuração one-time no RubyGems (ação admin), por isso o fallback fica documentado.

**Alternativa rejeitada**: `gem push` manual no terminal do mantenedor — frágil, depende de MFA interativa, sem gate de CI.

### D4. Release em duas peças: script local (prep) + workflow (publish)
**Decisão**: `scripts/release.sh` faz só a **preparação** local (bump de versão, rotação de CHANGELOG, commit, tag, push). A **publicação** acontece no `release.yml` disparado pelo push da tag. O script **nunca** faz `gem push`.

**Por quê**: separa intenção (humano corta a tag) de execução (CI publica com gate verde e credencial OIDC). Se o CI falhar, a tag existe mas o gem não é publicado — rollback é deletar a tag e retag. Publicar do laptop pula o gate de CI e vaza credenciais.

```yaml
# .github/workflows/release.yml
on:
  push:
    tags: ['v*']
permissions:
  contents: write   # criar GitHub Release
  id-token: write   # OIDC para RubyGems trusted publishing
```

### D5. CI gate completo antes de publicar
**Decisão**: o job `verify` roda a matrix Ruby 3.2/3.3/3.4 com `rake spec` (SimpleCov ≥ 80%), `rubocop`, `steep check` e `rake generate:check`. `publish` tem `needs: verify`.

**Por quê**: o SDK toca emissão fiscal. Publicar com tipo quebrado, lint sujo ou código gerado fora de sync é inaceitável. `generate:check` garante que `lib/nfe/generated/` e `sig/` refletem o `openapi/` commitado.

### D6. Gem assinado/checksummed
**Decisão**: o `publish` gera `sha256sum nfe-io-X.Y.Z.gem` e anexa o `.gem` + `.sha256` ao GitHub Release. MFA obrigatória via `spec.metadata["rubygems_mfa_required"] = "true"`.

**Por quê**: checksum permite verificação independente do artefato; MFA obrigatória protege a conta do gem. Assinatura criptográfica completa (cert chain `gem cert`) é opcional/futura — checksum + OIDC + MFA já cobrem o essencial sem fricção de gestão de chaves.

### D7. Samples são scripts runnable, não snippets em docs
**Decisão**: cada sample é um arquivo Ruby executável (`ruby samples/x.rb`) que carrega `samples/config.rb` (lê env vars e instancia `$nfe`). Sample é demo de uso real, não template exaustivo.

**Por quê**: snippets em docs apodrecem; samples rodam e quebram se a compatibilidade quebrar (smoke test embutido). Os downloads usam `File.binwrite` para reforçar o contrato de `String` binária. `.env` no `.gitignore`.

### D8. MIGRATION.md com mapeamento completo + apêndices end-to-end
**Decisão**: além das tabelas classe/método, três apêndices: **vanilla** (script CLI), **Rails** (initializer + controller de webhook sobre `request.raw_post`), e referência a integradores. Cobre os 17 recursos.

**Por quê**: a migração v0.3.x → v1 é um salto grande (global estático → instância; rest-client → stdlib; classes achatadas → 17 recursos snake_case). A audiência primária do SDK Ruby são scripts e apps Rails; cobrir esses cenários reduz a fricção da maioria da base.

### D9. Webhook signature documentado com o esquema CORRETO
**Decisão**: README, MIGRATION e skill documentam `X-Hub-Signature` + **HMAC-SHA1** sobre os **bytes crus** do corpo, hex case-insensitive, prefixo `sha1=`, comparação timing-safe. Alertam explicitamente que o esquema antigo (`X-NFe-Signature` + SHA-256) presente em docs de distribuição está **errado** vs produção.

**Por quê**: recon confirmou (probe em produção) que o esquema real é HMAC-SHA1 com `X-Hub-Signature`. Em Ruby: ler `request.raw_post` (Rails) / `request.body.read` (Rack) antes de parsear JSON, `OpenSSL::HMAC.hexdigest("SHA1", secret, body)`, comparar com `Rack::Utils.secure_compare` ou implementação timing-safe própria. Re-serializar o JSON quebra a verificação.

### D10. Skill de IA espelha a do Node, adaptada a Ruby idiomático
**Decisão**: `skills/nfeio-ruby-sdk/SKILL.md` segue a estrutura da `nfeio-node-sdk` (front-matter com gatilhos, quickstart, resource map, padrões core, pitfalls, decision tree) + `references/*.md` segmentados. Adapta idiomas: `Promise`→retorno síncrono, `Buffer`→`String` binária, camelCase→snake_case, union types→classes `Pending`/`Issued`, `instanceof`→`is_a?`/`case/in`.

**Por quê**: a skill do Node é a referência de padrões de SDK; manter paridade de estrutura facilita manutenção cruzada e dá ao agente um mapa idêntico ao das outras linguagens.

### D11. Política RC + beta antes do GA
**Decisão**: a primeira `v1.0.0` é precedida de `v1.0.0-rc.1` (publicado como prerelease no RubyGems, fora do `latest`) e um período de beta; issue crítica → `rc.2` reinicia o relógio. Patches (`v1.0.1`) podem sair direto.

**Por quê**: SDK fiscal — bug em emissão = nota fiscal errada = problema legal. Pré-releases no RubyGems não viram `latest` (consumidores precisam opt-in com `--pre`/`= 1.0.0.rc.1`), então o beta não afeta quem usa `~> 1.0` por engano.

## Risks / Trade-offs

| Risco | Mitigação |
|---|---|
| OIDC trusted publishing exige setup admin one-time no RubyGems | Fallback documentado: secret `RUBYGEMS_API_KEY` + `GEM_HOST_API_KEY` no job `publish` |
| Publicação no RubyGems é irreversível por versão (yank não apaga) | RC + beta antes do GA; `--dry-run` no release.sh; gate de CI obrigatório |
| Cobertura ≥ 80% pode forçar testes triviais em `Data.define` | `lib/nfe/generated/` excluído do denominador SimpleCov; value objects puros dispensam teste mecânico |
| `MIGRATION.md` completo é longo de manter | Aceito; é a referência canônica, versionada por tag (stale pós-release é aceitável) |
| Pré-release no RubyGems poluindo `latest` | Pré-releases (`-rc`/`-beta`) não são resolvidos por `~> 1.0`; só com opt-in explícito |
| `release.sh` em PowerShell/Windows | Linux/macOS apenas; dev Windows usa WSL. CONTRIBUTING explicita |
| Tag empurrada mas CI falha → gem não publicado | Esperado: rollback é deletar a tag e retag após corrigir; GitHub Release não é criado sem `verify` verde |
| Página de docs depende do time de `nfeio-docs` | Não bloqueia a release do gem; é tarefa coordenada e linkável depois |

## Resolved (durante recon — 2026-06-24)

### R1. Nome do gem e bump de versão
**Decisão**: nome `nfe-io` mantido (não renomear). Bump `0.3.2 → 1.0.0`. Greenfield: nada reaproveitado do código atual. Confirmado pelo mantenedor.

### R2. Branch de legado
**Decisão**: `master` atual (v0.3.2, rest-client) vai para a branch `0.x-legacy` (congelada, sem manutenção). v1 é desenvolvida em `master`. CONTRIBUTING e MIGRATION documentam.

### R3. Tradução EN fica fora da v1.0
**Decisão**: README e MIGRATION em pt-BR. EN entra como feature futura se houver demanda concreta de integrador internacional.

## Open Questions (precisam de decisão sua)

- **Duração exata do período de beta** — 7 ou 14 dias para o `v1.0.0` GA? Tasks §12.3 deixa "mínimo definido na política"; cravar o número antes de cortar o `rc.1`.
- **Setup de OIDC no RubyGems** — quem tem acesso admin da conta `nfe-io` no RubyGems para vincular o repo `nfe/client-ruby` ao trusted publishing? Se indisponível na data, ativar o fallback `RUBYGEMS_API_KEY` (D3).
- **Janela da página de docs** — coordenar com o time de `nfeio-docs` se a página Ruby sai junto com o GA ou logo depois (Tasks §10).
