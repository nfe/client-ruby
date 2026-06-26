---
title: Cálculo de impostos (tax_calculation) no SDK Ruby da NFE.io
sidebar_label: Cálculo de impostos
sidebar_position: 14
description: Execução do motor de regras tributárias por tenant, com retorno do detalhamento de impostos por item, no SDK Ruby da NFE.io.
---

# Cálculo de impostos (`tax_calculation`)

O recurso `tax_calculation` executa o motor de regras tributárias de um tenant e
devolve o detalhamento de impostos por item. Faz parte da família `cte`, servida
por `api.nfse.io`, e usa a `api_key` (emissão é capacidade central, não consulta
de dados).

## Métodos públicos

```ruby
tax_calculation.calculate(tenant_id, request)
# => Nfe::Generated::CalculoImpostosV1::CalculateResponse
```

O `request` é um `Hash` com chaves em camelCase. Para type-safety, você pode
construí-lo a partir de `Nfe::Generated::CalculoImpostosV1::CalculateRequest#to_h`.

## Exemplo

### Calcular impostos de um pedido

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))

resultado = client.tax_calculation.calculate(
  "tenant-123",
  {
    operationType: "Sale",
    items: [
      { code: "SKU-1", quantity: 2, unitAmount: 49.90, ncm: "61091000" }
    ]
  }
)

resultado
```

:::warning Validação fail-fast (sem HTTP)
Antes de qualquer requisição, o SDK valida que `tenant_id` é não vazio e que o
`request` é um `Hash` contendo `operation_type` (ou `operationType`) e um array
`items` **não vazio**. Caso contrário, levanta `Nfe::InvalidRequestError`.
:::

:::tip Use o request tipado quando quiser segurança de tipos
`CalculateRequest#to_h` ajuda a montar o corpo com a forma esperada (ICMS, IPI,
PIS, COFINS, II, ICMS-UF-Dest etc.) sem digitar as chaves à mão.
:::

## Veja também

- [Tabelas tributárias (tax_codes)](./tax-codes.md) — códigos de referência para montar o request.
- [Inscrições estaduais (state_taxes)](./state-taxes.md) — outro recurso da família `cte`.
