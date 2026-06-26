---
title: Pessoas físicas (natural_people) no SDK Ruby da NFE.io
sidebar_label: Pessoas físicas
sidebar_position: 9
description: CRUD de pessoas físicas (tomadores PF) escopadas por empresa, com create_batch e find_by_tax_number, no SDK Ruby da NFE.io.
---

# Pessoas físicas (`natural_people`)

O recurso `natural_people` gerencia pessoas físicas (tomadores PF) **escopadas por
empresa**, sob `/companies/{id}/naturalpeople`. Faz parte da família `main`,
servida por `api.nfe.io` (`/v1`), e usa a `api_key`.

## Métodos públicos

```ruby
natural_people.list(company_id)                                  # => Nfe::ListResponse
natural_people.create(company_id, data)                          # => Nfe::NaturalPerson
natural_people.retrieve(company_id, natural_person_id)           # => Nfe::NaturalPerson
natural_people.update(company_id, natural_person_id, data)       # => Nfe::NaturalPerson
natural_people.delete(company_id, natural_person_id)             # => nil
natural_people.create_batch(company_id, list)                    # => Array<Nfe::NaturalPerson>
natural_people.find_by_tax_number(company_id, federal_tax_number) # => Nfe::NaturalPerson | nil
```

:::note `list` não pagina
`list(company_id)` devolve todas as pessoas físicas da empresa em um único
`Nfe::ListResponse` (paridade com o SDK Node), sem cursores nem páginas.
:::

## Exemplos

### Criar e recuperar

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))
company_id = "55df4dc6b6cd9007e4f13ee8"

person = client.natural_people.create(
  company_id,
  name: "Maria da Silva",
  federalTaxNumber: "39053344705"
)

client.natural_people.retrieve(company_id, person.id)
```

### Criar várias e localizar por CPF

```ruby
client.natural_people.create_batch(company_id, [
  { name: "João Souza", federalTaxNumber: "11144477735" },
  { name: "Ana Lima",   federalTaxNumber: "39053344705" }
])

# find_by_tax_number normaliza para 11 dígitos antes de filtrar:
client.natural_people.find_by_tax_number(company_id, "390.533.447-05")
```

:::tip `create_batch` é sequencial
As criações são executadas **em sequência** e devolvidas na ordem da lista
informada — não em paralelo.
:::

## Veja também

- [Pessoas jurídicas](./legal-people.md) — o equivalente para PJ.
- [Empresas](./companies.md) — o escopo (`company_id`) destes recursos.
- [Consulta de CPF](./natural-person-lookup.md) — situação cadastral de uma PF na Receita.
