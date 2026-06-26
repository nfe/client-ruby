---
title: Consulta de endereços (addresses) no SDK Ruby da NFE.io
sidebar_label: Endereços
sidebar_position: 11
slug: enderecos
description: Consulta de endereços por CEP, por termo livre e por filtro OData no recurso addresses do SDK Ruby da NFE.io.
---

# Consulta de endereços (`addresses`)

O recurso `addresses` consulta endereços por CEP, por termo livre ou por filtro
OData. Faz parte da família de **dados** `addresses`, servida por
`address.api.nfe.io/v2`. Como host já embute a versão, os caminhos são usados como
estão.

:::note Família de dados — configure `data_api_key`
`addresses` é um serviço de **dados**: usa a `data_api_key` quando presente, com
**fallback** para a `api_key`. Configure `data_api_key:` (ou `NFE_DATA_API_KEY`)
para separar a chave de consulta da chave de emissão. Veja
[Configuração](../configuration.md).
:::

## Métodos públicos

```ruby
addresses.lookup_by_postal_code(postal_code)   # => Nfe::AddressLookupResponse
addresses.lookup_by_term(term)                 # => Nfe::AddressLookupResponse
addresses.search(filter: nil)                  # => Nfe::AddressLookupResponse
```

## Exemplos

### Consultar por CEP

```ruby
require "nfe"

client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: ENV.fetch("NFE_DATA_API_KEY")
)

resposta = client.addresses.lookup_by_postal_code("01310-100")
resposta.addresses
```

:::warning CEP é validado antes do HTTP
O CEP precisa ter **8 dígitos** (separadores são removidos). Um CEP inválido
levanta `Nfe::InvalidRequestError` **antes** de qualquer requisição. Veja
[Tratamento de erros](../errors.md).
:::

### Consultar por termo livre

```ruby
client.addresses.lookup_by_term("Avenida Paulista, São Paulo")
```

Um `term` vazio ou só com espaços levanta `Nfe::InvalidRequestError`.

### Buscar com filtro OData

```ruby
client.addresses.search(filter: "city eq 'São Paulo'")

# Sem filtro: lista o que a API retornar por padrão.
client.addresses.search
```

:::note `filter` é opaco
O argumento `filter:` é repassado verbatim como `$filter` na query — o SDK não
interpreta nem valida a expressão OData.
:::

## Veja também

- [Configuração](../configuration.md) — modelo de duas chaves e `data_api_key`.
- [Consulta de CNPJ](./legal-entity-lookup.md) e [Consulta de CPF](./natural-person-lookup.md) — outras famílias de dados.
