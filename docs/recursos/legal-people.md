---
title: Pessoas jurídicas (legal_people) no SDK Ruby da NFE.io
sidebar_label: Pessoas jurídicas
sidebar_position: 8
slug: pessoas-juridicas
description: CRUD de pessoas jurídicas (tomadores PJ) escopadas por empresa, com create_batch e find_by_tax_number, no SDK Ruby da NFE.io.
---

# Pessoas jurídicas (`legal_people`)

O recurso `legal_people` gerencia pessoas jurídicas (tomadores PJ) **escopadas por
empresa**, sob `/companies/{id}/legalpeople`. Faz parte da família `main`, servida
por `api.nfe.io` (`/v1`), e usa a `api_key`.

## Métodos públicos

```ruby
legal_people.list(company_id)                                  # => Nfe::ListResponse
legal_people.create(company_id, data)                          # => Nfe::LegalPerson
legal_people.retrieve(company_id, legal_person_id)             # => Nfe::LegalPerson
legal_people.update(company_id, legal_person_id, data)         # => Nfe::LegalPerson
legal_people.delete(company_id, legal_person_id)               # => nil
legal_people.create_batch(company_id, list)                    # => Array<Nfe::LegalPerson>
legal_people.find_by_tax_number(company_id, federal_tax_number) # => Nfe::LegalPerson | nil
```

:::note `list` não pagina
`list(company_id)` devolve todas as pessoas jurídicas da empresa em um único
`Nfe::ListResponse` (paridade com o SDK Node), sem cursores nem páginas.
:::

## Exemplos

### Criar e recuperar

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))
company_id = "55df4dc6b6cd9007e4f13ee8"

person = client.legal_people.create(
  company_id,
  name: "Banco do Brasil SA",
  federalTaxNumber: "00000000000191"
)

client.legal_people.retrieve(company_id, person.id)
```

### Criar várias de uma vez

```ruby
people = client.legal_people.create_batch(company_id, [
  { name: "Fornecedor A LTDA", federalTaxNumber: "12345678000199" },
  { name: "Fornecedor B LTDA", federalTaxNumber: "98765432000188" }
])
```

:::tip `create_batch` é sequencial
Diferente do SDK Node (que usa `Promise.all`), o `create_batch` executa as
criações **em sequência** e devolve os resultados na mesma ordem da lista.
:::

### Localizar por CNPJ

```ruby
person = client.legal_people.find_by_tax_number(company_id, "12.345.678/0001-99")
```

:::note Filtragem no cliente
`find_by_tax_number` chama `list` e filtra localmente, normalizando os dígitos do
CNPJ antes de comparar.
:::

## Veja também

- [Pessoas físicas](./natural-people.md) — o equivalente para PF.
- [Empresas](./companies.md) — o escopo (`company_id`) destes recursos.
- [Consulta de CNPJ](./legal-entity-lookup.md) — dados cadastrais de uma PJ na Receita.
