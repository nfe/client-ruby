---
title: Inscrições estaduais (state_taxes) no SDK Ruby da NFE.io
sidebar_label: Inscrições estaduais
sidebar_position: 16
description: CRUD das inscrições estaduais (Inscrição Estadual) de uma empresa, com paginação cursor-style, no SDK Ruby da NFE.io.
---

# Inscrições estaduais (`state_taxes`)

O recurso `state_taxes` gerencia as inscrições estaduais (Inscrição Estadual) de
uma empresa. Faz parte da família `cte`, servida por
`api.nfse.io` (`/v2/companies/{companyId}/statetaxes`), e usa a `api_key`.

## Métodos públicos

```ruby
state_taxes.list(company_id, starting_after: nil, ending_before: nil, limit: nil)
# => Nfe::ListResponse

state_taxes.create(company_id, data)                  # => Nfe::NfeStateTax
state_taxes.retrieve(company_id, state_tax_id)        # => Nfe::NfeStateTax
state_taxes.update(company_id, state_tax_id, data)    # => Nfe::NfeStateTax
state_taxes.delete(company_id, state_tax_id)          # => nil
```

:::note Lista cursor-style
`list` usa paginação **cursor-style** (`starting_after`/`ending_before`/`limit`) e
devolve um `Nfe::ListResponse` — diferente das listas page-style de
[tax_codes](./tax-codes.md). Veja [Paginação](../pagination.md).
:::

## Exemplos

### Criar e recuperar uma inscrição

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))
company_id = "55df4dc6b6cd9007e4f13ee8"

ie = client.state_taxes.create(
  company_id,
  code: "SP",
  taxNumber: "1234567890"
)

client.state_taxes.retrieve(company_id, ie.id)
```

:::tip O corpo é embrulhado em `stateTax`
Você passa apenas os atributos (em camelCase). O SDK embrulha o corpo como
`{ "stateTax": { ... } }` em `create`/`update` e desembrulha a resposta
automaticamente antes de hidratar `Nfe::NfeStateTax`.
:::

### Listar com cursor e atualizar

```ruby
pagina = client.state_taxes.list(company_id, limit: 50)
pagina.data.each { |ie| puts ie.code }

client.state_taxes.update(company_id, ie.id, taxNumber: "0987654321")
client.state_taxes.delete(company_id, ie.id)
```

## Veja também

- [Empresas](./companies.md) — o escopo (`company_id`) das inscrições.
- [Consulta de CNPJ](./legal-entity-lookup.md) — consultar a IE de terceiros para emissão.
- [Paginação](../pagination.md) — paginação cursor-style.
