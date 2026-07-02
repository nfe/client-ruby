# Design — add-ruby-foundation

## Context

A gem `nfe-io` atual (v0.3.2) é Ruby 2.4-era: depende de `rest-client`, usa estado global (`@@api_key`), objetos dinâmicos (`Nfe::NfeObject` com `method_missing`), e cobre só quatro recursos. Os SDKs de referência já estabeleceram o padrão de paridade que a v1 Ruby deve seguir:

- **Node.js** (`client-nodejs`, `nfe-io`): `NfeClient` + recursos como properties *lazy*, zero deps de runtime, multi-base-URL, polling de 202, hierarquia de erros tipada, tipos gerados de OpenAPI.
- **PHP** (`nfe/client-php`): mesma superfície, PHPStan L8, value objects, `Config::baseUrlForApi(family)` como fonte única de hosts.

A filosofia de referência é **Stripe**: cliente único + acessores de recurso, serviços *hand-written* sobre modelos gerados. A v1 Ruby **não é refactor; é rewrite greenfield** — nada de `lib/nfe/*` legado é importado. Esta change estabelece o terreno onde as changes seguintes (HTTP core, codegen de OpenAPI, `Nfe::Client`, recursos) vão crescer. É a change **foundational**, sem dependências a montante.

`nfeio-docs` (symlink `nfeio-docs/`) é a **fonte da verdade** para o comportamento da API; os SDKs Node e PHP são a **referência** para padrões e superfície de recursos.

## Goals / Non-Goals

**Goals:**
- Piso Ruby 3.2+ definido e enforced (gemspec `required_ruby_version` + CI matrix 3.2/3.3/3.4)
- Namespace raiz `Nfe`, entrypoint único `Nfe::Client.new(api_key:)` estilo Stripe, acessores *lazy* `snake_case` para os 17 recursos
- `# frozen_string_literal: true` na primeira linha de **todo** arquivo `.rb` (enforçado por RuboCop)
- **Zero dependências de runtime** — somente stdlib (`net/http`, `json`, `openssl`, `uri`, `securerandom`, `stringio`, `time`, `base64`); `rest-client` removido
- Value objects imutáveis via `Data.define` (Ruby 3.2+)
- Rigor de tipos paralelo ao Node (`.d.ts`) e PHP (PHPStan L8): RBS shipado em `sig/`, type-check com Steep, lint com RuboCop
- Testes com RSpec, cobertura >= 80% via SimpleCov, gate no CI
- `Configuration` como **fonte única** do mapa multi-base-URL (nenhum recurso hard-coda URL)
- Branch `0.x-legacy` congelado; v1 em `master`

**Non-Goals:**
- Camada HTTP (`Net::HTTP` wrapper, retry, rate-limit) — change futura
- Codegen de OpenAPI (gerador + `lib/nfe/generated/` + `sig/nfe/generated/`) — change futura
- Qualquer corpo de recurso de API (CRUD, downloads, polling, 202) — changes futuras
- Suporte a Ruby < 3.2 ou shim de compat com a v0.x
- Backport de fixes para o `0.x-legacy` (fica congelado)
- Publicação no RubyGems (change de release)

## Decisions

### D1. Piso Ruby 3.2 (não 3.1, não 3.3)
**Decisão**: `spec.required_ruby_version = ">= 3.2"`; CI em 3.2 / 3.3 / 3.4.
**Por quê**: `Data.define` — base dos value objects imutáveis do SDK — só existe a partir do Ruby **3.2**. 3.1 não tem `Data`. 3.2 é o piso natural e ainda amplamente suportado. 3.3 e 3.4 entram como alvos de CI, não como piso. *Alternativa rejeitada*: piso 3.1 + `Struct`/`Comparable` artesanal — perde a imutabilidade e a ergonomia de `Data.define` por nada.

### D2. Gem name permanece `nfe-io` (sem rename)
**Decisão**: `spec.name = "nfe-io"`, bump 0.3.2 → 1.0.0.
**Por quê**: Diferente do PHP (que renomeou `nfe/nfe` → `nfe/client-php`), no RubyGems o nome `nfe-io` já é o canônico e está publicado. Renomear fragmentaria a descoberta e quebraria `gem "nfe-io"` existente. O bump de **major** (SemVer) comunica a quebra; quem precisa do código antigo fixa `~> 0.3`. *Alternativa rejeitada*: novo nome `nfe-io-client` — confunde sem ganho.

### D3. Layout `lib/nfe/`, gerados isolados em `lib/nfe/generated/`
**Decisão**: código *hand-written* em `lib/nfe/...`; modelos gerados em `lib/nfe/generated/`; RBS em `sig/` (com `sig/nfe/generated/` para os `.rbs` gerados). `lib/nfe/generated/` **nunca** é editado à mão.
**Por quê**: Espelha a separação Node (`src/generated/`) e PHP (`src/Generated/`). Mantém o gerador idempotente — regenerar não toca em código artesanal. RuboCop e (inicialmente) Steep excluem `generated/` porque são confiáveis por construção. *Alternativa rejeitada*: misturar gerado e *hand-written* — envenena diffs e regen.

### D4. Entrypoint `Nfe::Client.new(api_key:)` + acessores *lazy* `snake_case`
**Decisão**: cliente único estilo Stripe. Acessores `snake_case` (`client.service_invoices`, `client.legal_entity_lookup`, ...) que instanciam o recurso na primeira leitura (memoizado), passando o HTTP client apropriado por família.
**Por quê**: Paridade com Node (`client.serviceInvoices`) e PHP (`$nfe->serviceInvoices`), adaptado ao idioma Ruby (`snake_case`). *Lazy* evita instanciar 17 recursos + N HTTP clients no `new`; também permite que um client só com `data_api_key` funcione para recursos de dados e só falhe (`Nfe::ConfigurationError`) quando um recurso `main` é tocado sem `api_key`. Substitui o estado global `@@api_key` do legado por estado de instância. *Alternativa rejeitada*: métodos globais `Nfe.service_invoices` — estado global, não thread-safe, contraria Stripe.

### D5. Value objects via `Data.define`, não `Struct` nem `OpenStruct`
**Decisão**: todo modelo de domínio é `Data.define(:campo1, :campo2) do ... end`, imutável, com keyword args.
**Por quê**: `Data` (3.2+) é imutável por padrão, tem `==`/`hash`/`with` de graça, e é o idioma moderno para value objects. `Struct` é mutável; `OpenStruct` é lento e sem tipos. Substitui o `NfeObject` com `method_missing` do legado (frágil, sem tipos, sem RBS possível). *Alternativa rejeitada*: classes manuais com `attr_reader` + `initialize` — boilerplate que `Data.define` elimina.

### D6. Zero deps de runtime — só stdlib
**Decisão**: nenhum `add_dependency`. HTTP via `net/http`; JSON via `json`; HMAC/PKCS12 via `openssl`; URLs via `uri`; IDs via `securerandom`; buffers via `stringio`; datas via `time`; encode via `base64`.
**Por quê**: Paridade com Node (zero-dep) e PHP (só extensões). `rest-client` (dep do legado) é desnecessário — `Net::HTTP` cobre tudo, inclusive multipart e download binário. Menos superfície de supply-chain, menos conflito de versão no Bundler do consumidor. *Alternativa rejeitada*: `faraday`/`httparty` — adiciona dep transitiva sem ganho sobre stdlib.

### D7. Rigor de tipos: RBS shipado + Steep no CI
**Decisão**: assinaturas `.rbs` em `sig/` versionadas e empacotadas na gem; `steep check` e `rbs validate` no CI; lint com RuboCop.
**Por quê**: Paralelo ao Node (`.d.ts`) e PHP (PHPStan L8). RBS é o caminho oficial de tipos no Ruby; shipar `sig/` na gem dá tipos a quem usa Steep/Sorbet downstream. O gerador emite `.rbs` junto dos value objects, mantendo modelos e tipos em sincronia. *Alternativa rejeitada*: Sorbet (`.rbi` + `sig do ... end` inline) — mais intrusivo no código, exige runtime; RBS é externo e idiomático.

### D8. Downloads → `String` binária; async → retorno síncrono
**Decisão**: métodos de download retornam `String` com `force_encoding(Encoding::ASCII_8BIT)` (binary-safe). Toda chamada é síncrona (sem Promises/async); o contrato 202 vira value objects discriminados (Pending vs. Issued) e o polling é um loop síncrono.
**Por quê**: Ruby não tem `Buffer`; a convenção binária é `String` ASCII-8BIT. Node usa `Promise`/`Buffer`; PHP usa `string` raw bytes — Ruby segue o PHP. FlowStatus terminal (`Issued`/`IssueFailed`/`Cancelled`/`CancelFailed`) gateia o polling. Esta change só **documenta** a convenção; a implementação vem nas changes de HTTP/recurso.

### D9. `Configuration` como fonte única do mapa multi-base-URL
**Decisão**: `Nfe::Configuration#base_url_for(family)` resolve as 6 famílias; nenhum recurso hard-coda host. Família desconhecida → host `main` como default seguro.
**Por quê**: Paridade com `Config::baseUrlForApi(family)` do PHP. Centraliza a única coisa que difere entre recursos (host). Mapa confirmado: `main` → `https://api.nfe.io` (o `/v1` é fornecido pelo `api_version` do recurso, URL efetiva `https://api.nfe.io/v1/...`); `addresses` → `https://address.api.nfe.io/v2` (exceção documentada: o `/v2` é parte do host); `nfe-query` → `https://nfe.api.nfe.io`; `legal-entity` → `https://legalentity.api.nfe.io`; `natural-person` → `https://naturalperson.api.nfe.io`; `cte` → `https://api.nfse.io`.

### D10. Branch `0.x-legacy` congelado; v1 em `master`
**Decisão**: snapshot do master atual (v0.3.2) para `0.x-legacy` antes da limpeza; v1 desenvolvida no `master`; CI só no `master`.
**Por quê**: Diferente do PHP (que pôs v3 num branch e deixou `master` no v2), aqui a v1 é o futuro e merece o `master`; o legado vai para um branch nominado e congelado. Quem precisa do antigo fixa `~> 0.3` (resolve do `0.x-legacy`). *Alternativa rejeitada*: deixar o legado no `master` e a v1 num branch — inverte a expectativa de "master = versão atual".

### D11. Sem shim de compatibilidade v0.x
**Decisão**: zero compat no nível de código. `require "nfe"` continua válido como entrypoint, mas `Nfe.api_key(...)` e os objetos dinâmicos somem; a API passa a ser `Nfe::Client.new(api_key:)`. Migrar é leitura do `MIGRATION.md`.
**Por quê**: Shim envenena o namespace novo (estado global, `method_missing`). Stripe não faz isso entre majors. Quem não pode migrar fixa `~> 0.3`.

## Risks / Trade-offs

| Risco | Mitigação |
|---|---|
| Piso Ruby 3.2 exclui apps presos em 2.x/3.0/3.1 | Aceitável — `Data.define` exige 3.2; usuários legados ficam em `~> 0.3` (branch `0.x-legacy`) |
| Consumidores confundem v0.x (entrypoint global) com v1 (`Nfe::Client`) | `MIGRATION.md` explícito + bump de major (SemVer) + banner no `README` |
| `Net::HTTP` exige mais código que `rest-client` (retry, multipart, timeout manuais) | Aceitável — isolado na camada HTTP (change futura); zero-dep vale o custo; paridade com Node/PHP |
| Steep em código gerado pode gerar ruído | `lib/nfe/generated/` excluído do check estrito inicial; refinar conforme o codegen amadurece |
| Gate de cobertura 80% pode travar PRs cedo | Smoke de fundação (version/client/configuration) já cobre; o gate cresce com os recursos |
| `Gemfile.lock` ausente reduz reprodutibilidade local | Convenção de gem lib (não commitar lock); CI usa `bundler-cache` para estabilidade |
| Família de host desconhecida roteada para `main` pode mascarar bug de roteamento | Default seguro documentado; recon contínuo contra o Node SDK valida cada família |

## Open Questions

- **Política pública do legado**: optei por "frozen indefinido" no branch `0.x-legacy`. Se quisermos um EOL com data formal (ex.: "2027-01-01"), este é o lugar de capturar.
- **`.ruby-version` de desenvolvimento**: aponto `3.4` (mais recente da matrix) para o dev local; o piso suportado permanece `3.2` via gemspec. Confirmar se o time prefere fixar `3.2` no `.ruby-version`.
