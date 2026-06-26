---
title: Tabelas tributárias (tax_codes) no SDK Ruby da NFE.io
sidebar_label: Tabelas tributárias
sidebar_position: 15
description: Listas de referência do CT-e — códigos de operação, finalidades de aquisição e perfis tributários — com paginação page-style no SDK Ruby da NFE.io.
---

# Tabelas tributárias (`tax_codes`)

O recurso `tax_codes` expõe as quatro listas de referência consumidas ao montar um
CT-e: códigos de operação, finalidades de aquisição e os perfis tributários do
emitente e do destinatário. Faz parte da família `cte`, servida por `api.nfse.io`,
e usa a `api_key`.

## Métodos públicos

```ruby
tax_codes.list_operation_codes(page_index: nil, page_count: nil)        # => Nfe::TaxCodePaginatedResponse
tax_codes.list_acquisition_purposes(page_index: nil, page_count: nil)   # => Nfe::TaxCodePaginatedResponse
tax_codes.list_issuer_tax_profiles(page_index: nil, page_count: nil)    # => Nfe::TaxCodePaginatedResponse
tax_codes.list_recipient_tax_profiles(page_index: nil, page_count: nil) # => Nfe::TaxCodePaginatedResponse
```

:::note Paginação page-style (1-based)
Diferente das listas cursor-style do SDK, estes endpoints paginam por página
**1-based** (`page_index`/`page_count`) e devolvem um `Nfe::TaxCodePaginatedResponse`
(não um `Nfe::ListResponse`). Os parâmetros de paginação só são enviados quando
informados.
:::

## Exemplos

### Listar códigos de operação

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))

# Sem paginação explícita:
client.tax_codes.list_operation_codes

# Página 2, 20 itens (page_index é 1-based):
client.tax_codes.list_operation_codes(page_index: 2, page_count: 20)
```

### Listar perfis tributários e finalidades

```ruby
client.tax_codes.list_acquisition_purposes
client.tax_codes.list_issuer_tax_profiles
client.tax_codes.list_recipient_tax_profiles
```

## Veja também

- [Cálculo de impostos (tax_calculation)](./tax-calculation.md) — consome estes códigos.
- [Paginação](../pagination.md) — diferenças entre listas page-style e cursor-style.
