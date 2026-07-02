# Contribuindo com o `nfe-io`

Obrigado por contribuir com o SDK Ruby da NFE.io. Este guia cobre branches,
setup local, toolchain, convenções de código, arquivos gerados, commits e a
cadência de release.

## Branches

- **`master`** — a `v1` **ativa**. Toda contribuição (features, correções, docs)
  vai aqui.
- **`0.x-legacy`** — a série `0.x` **congelada** (baseada em `rest-client`). Não
  recebe manutenção nem backports. **PRs contra ela serão fechados.**

Abra a sua branch a partir de `master` e direcione o PR para `master`.

## Setup local

Requer **Ruby 3.2+** (CI roda em 3.2, 3.3 e 3.4). Use um gerenciador de versão:

```sh
# rbenv
rbenv install 3.3.0 && rbenv local 3.3.0

# ou asdf
asdf install ruby 3.3.0 && asdf local ruby 3.3.0
```

Instale as dependências de desenvolvimento (a gem tem **zero dependências de
runtime**; tudo abaixo é só ferramenta de dev):

```sh
bundle install
# atalho equivalente, se preferir:
bin/setup
```

## Toolchain

| Comando | Faz |
|---|---|
| `bundle exec rake spec` | Roda os testes (RSpec) com gate de cobertura **SimpleCov ≥ 80%**. |
| `bundle exec rake rubocop` | Lint (RuboCop + `rubocop-rspec`). |
| `bundle exec rake steep` | Type-check de `lib/` contra `sig/` (Steep). |
| `bundle exec rake rbs` | Valida as assinaturas RBS em `sig/`. |
| `bundle exec rake generate` | Gera value objects + RBS a partir de `openapi/*.{yaml,json}`. |
| `bundle exec rake generate:check` | Falha se o código gerado divergir das specs OpenAPI. |
| `bundle exec rake` | Pipeline completo: `generate:check` → `spec` → `rubocop` → `steep` → `rbs`. |

Rode `bundle exec rake` antes de abrir o PR — é o mesmo conjunto de gates que o
CI executa.

## Convenções de código

- Todo arquivo `.rb` começa com `# frozen_string_literal: true`.
- **Strings com aspas duplas.**
- Nomes de métodos e variáveis em `snake_case`.
- **Argumentos nomeados** (keyword args) na API pública.
- Value objects **imutáveis** via `Data.define`.
- Documentação e comentários em **pt-BR**.

O RuboCop é a fonte da verdade para estilo; rode `bundle exec rake rubocop` (e
`-A` para autocorreções seguras) antes de commitar.

## Arquivos gerados

Parte do código é **gerado** a partir das specs OpenAPI e **nunca deve ser
editada à mão**:

- `lib/nfe/generated/**` — value objects gerados.
- A parte gerada de `sig/**` (assinaturas RBS dos modelos).

Para alterar um modelo gerado:

1. Atualize a spec correspondente em `openapi/*.{yaml,json}`.
2. Rode `bundle exec rake generate` para regenerar código + RBS.
3. **Commite a spec e o código gerado juntos**, no mesmo PR.

O CI roda `generate:check` e **falha** se o gerado divergir das specs — ou seja,
um PR que edita o gerado à mão sem atualizar a spec não passa.

> Os DTOs **escritos à mão** (ex.: `Nfe::Company`, `Nfe::ServiceInvoice`,
> `Nfe::NfeFileResource`) ficam fora de `lib/nfe/generated/` e podem ser editados
> normalmente.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/pt-br/):

```
feat: adiciona suporte a inutilização em lote de NFC-e
fix: corrige extração de invoice_id no Location de 202
docs: expande seção de webhooks no README
chore(release): 1.1.0
```

Tipos comuns: `feat`, `fix`, `docs`, `chore` (use `chore(release)` para o commit
de release).

## Fluxo OpenSpec

Mudanças de contrato/comportamento passam pelo OpenSpec: as propostas ficam em
`openspec/changes/` (e os specs arquivados em `openspec/specs/`). Abra/atualize a
change correspondente ao seu PR quando a alteração mudar o contrato do SDK.

## Cadência de release

O projeto segue [SemVer](https://semver.org/lang/pt-BR/):

- **patch** (`1.0.x`) — correções. Liberadas direto após o CI ficar verde.
- **minor** / **major** — novas capacidades / quebras de contrato. Precedidas de
  um ciclo de **release candidate** (`-rc.N`) e **beta** (`-beta.N`) antes do
  release estável.

Atualize o [`CHANGELOG.md`](CHANGELOG.md) (formato Keep a Changelog) no mesmo PR
da mudança.
