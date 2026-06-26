---
title: Consulta de NFC-e (consumer_invoice_query) no SDK Ruby da NFE.io
sidebar_label: Consulta de NFC-e
sidebar_position: 18
description: Consulta de cupom fiscal NFC-e (CFe-SAT) por chave de acesso — recuperação e download de XML — no SDK Ruby da NFE.io.
---

# Consulta de NFC-e (`consumer_invoice_query`)

O recurso `consumer_invoice_query` consulta cupons fiscais NFC-e (CFe-SAT) já
emitidos, pela chave de acesso. Faz parte da família de **dados** `nfe_query`,
servida por `nfe.api.nfe.io` (`/v1`, caminho `/coupon/`).

:::warning Não confunda com a emissão de NFC-e
Este recurso é **distinto** de `consumer_invoices` (emissão de NFC-e): host e
versão de API diferentes. Aqui apenas recuperamos e baixamos um cupom **já
emitido**.
:::

:::note Família de dados — configure `data_api_key`
Esta é uma família de **dados**: usa a `data_api_key` quando presente, com
**fallback** para a `api_key`. Configure `data_api_key:` (ou `NFE_DATA_API_KEY`).
Veja [Configuração](../configuration.md).
:::

## Métodos públicos

```ruby
consumer_invoice_query.retrieve(access_key)     # => Nfe::TaxCoupon
consumer_invoice_query.download_xml(access_key) # => String (bytes ASCII-8BIT)
```

## Exemplos

### Recuperar um cupom e baixar o XML

```ruby
require "nfe"

client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: ENV.fetch("NFE_DATA_API_KEY")
)

chave = "35200114200166000187650010000000071234567890"

cupom = client.consumer_invoice_query.retrieve(chave)

xml = client.consumer_invoice_query.download_xml(chave)
File.binwrite("nfce.xml", xml)
```

:::warning Chave de acesso é validada antes do HTTP
A chave de acesso precisa ter **44 dígitos**. Uma chave inválida levanta
`Nfe::InvalidRequestError` **antes** de qualquer requisição.
:::

:::tip `download_xml` retorna bytes binários
O retorno são os **bytes** do XML (`ASCII-8BIT`); grave com `File.binwrite`. Veja
o guia de [Downloads](../downloads.md).
:::

## Veja também

- [Consulta de NF-e (product_invoice_query)](./product-invoice-query.md) — o equivalente para NF-e.
- [Downloads](../downloads.md) — manipulação de XML binário.
- [Configuração](../configuration.md) — modelo de duas chaves.
