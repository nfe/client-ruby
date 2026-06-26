---
title: Consulta de CPF (natural_person_lookup) no SDK Ruby da NFE.io
sidebar_label: Consulta de CPF
sidebar_position: 13
description: Consulta da situação cadastral de uma pessoa física (CPF + data de nascimento) na Receita Federal pelo SDK Ruby da NFE.io.
---

# Consulta de CPF (`natural_person_lookup`)

O recurso `natural_person_lookup` consulta a situação cadastral de uma pessoa
física na Receita Federal a partir do CPF e da data de nascimento. Faz parte da
família de **dados** `natural_person`, servida por `naturalperson.api.nfe.io`. O
segmento de versão (`/v1`) já vem no caminho da requisição.

:::note Família de dados — configure `data_api_key`
Esta é uma família de **dados**: usa a `data_api_key` quando presente, com
**fallback** para a `api_key`. Configure `data_api_key:` (ou `NFE_DATA_API_KEY`).
Veja [Configuração](../configuration.md).
:::

## Métodos públicos

```ruby
natural_person_lookup.get_status(federal_tax_number, birth_date)
# => Nfe::NaturalPersonStatusResponse | nil
```

O `birth_date` aceita `String`, `Date`, `Time` ou `DateTime` — o SDK normaliza
para `YYYY-MM-DD` via `Nfe::DateNormalizer` antes da requisição.

## Exemplos

### Consultar a situação cadastral

```ruby
require "nfe"
require "date"

client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: ENV.fetch("NFE_DATA_API_KEY")
)

# Data como String:
client.natural_person_lookup.get_status("390.533.447-05", "1985-03-12")

# Ou como objeto Date/Time/DateTime:
client.natural_person_lookup.get_status("39053344705", Date.new(1985, 3, 12))
```

:::warning CPF e data validados antes do HTTP
O CPF é normalizado para **11 dígitos** e a data de nascimento é normalizada para
`YYYY-MM-DD`. Entradas inválidas levantam `Nfe::InvalidRequestError` **antes** de
qualquer requisição. Veja [Tratamento de erros](../errors.md).
:::

## Veja também

- [Consulta de CNPJ](./legal-entity-lookup.md) — o equivalente para PJ.
- [Pessoas físicas](./natural-people.md) — cadastro de tomadores PF na sua conta.
- [Configuração](../configuration.md) — modelo de duas chaves.
