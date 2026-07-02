---
title: Consulta de CNPJ (legal_entity_lookup) no SDK Ruby da NFE.io
sidebar_label: Consulta de CNPJ
sidebar_position: 12
slug: consulta-cnpj
description: Consulta cadastral de pessoa jurídica por CNPJ — dados básicos e inscrição estadual (inclusive para emissão) no SDK Ruby da NFE.io.
---

# Consulta de CNPJ (`legal_entity_lookup`)

O recurso `legal_entity_lookup` consulta dados cadastrais de pessoa jurídica por
CNPJ: informações básicas e inscrição estadual (inclusive a versão adequada para
emissão). Faz parte da família de **dados** `legal_entity`, servida por
`legalentity.api.nfe.io`. O segmento de versão (`/v2`) já vem no caminho de cada
requisição.

:::note Família de dados — configure `data_api_key`
Esta é uma família de **dados**: usa a `data_api_key` quando presente, com
**fallback** para a `api_key`. Configure `data_api_key:` (ou `NFE_DATA_API_KEY`).
Veja [Configuração](../configuration.md).
:::

## Métodos públicos

```ruby
legal_entity_lookup.get_basic_info(federal_tax_number, update_address: nil, update_city_code: nil)
# => Nfe::LegalEntityBasicInfoResponse

legal_entity_lookup.get_state_tax_info(state, federal_tax_number)
# => Nfe::LegalEntityStateTaxResponse

legal_entity_lookup.get_state_tax_for_invoice(state, federal_tax_number)
# => Nfe::LegalEntityStateTaxForInvoiceResponse

legal_entity_lookup.get_suggested_state_tax_for_invoice(state, federal_tax_number)
# => Nfe::LegalEntityStateTaxForInvoiceResponse
```

## Exemplos

### Dados básicos de um CNPJ

```ruby
require "nfe"

client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: ENV.fetch("NFE_DATA_API_KEY")
)

info = client.legal_entity_lookup.get_basic_info("00.000.000/0001-91")
info

# Opcionalmente força atualização de endereço/código de município:
client.legal_entity_lookup.get_basic_info(
  "00000000000191",
  update_address: true,
  update_city_code: true
)
```

:::warning CNPJ é validado antes do HTTP
O CNPJ precisa ter **14 dígitos** (separadores removidos). Um CNPJ inválido
levanta `Nfe::InvalidRequestError` **antes** de qualquer requisição.
:::

### Inscrição estadual para emissão

```ruby
# Inscrição estadual em um estado (UF):
client.legal_entity_lookup.get_state_tax_info("SP", "00000000000191")

# Versão adequada para uso em uma nota:
client.legal_entity_lookup.get_state_tax_for_invoice("SP", "00000000000191")

# Sugestão da inscrição estadual para a nota:
client.legal_entity_lookup.get_suggested_state_tax_for_invoice("SP", "00000000000191")
```

:::note UF e CNPJ validados localmente
`state` é validado como UF (case-insensitive) e o CNPJ como 14 dígitos. Qualquer
um inválido levanta `Nfe::InvalidRequestError` antes do HTTP.
:::

## Veja também

- [Consulta de CPF](./natural-person-lookup.md) — o equivalente para PF.
- [Inscrições estaduais (state_taxes)](./state-taxes.md) — cadastro de IE da sua empresa.
- [Configuração](../configuration.md) — modelo de duas chaves.
