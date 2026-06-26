---
title: Consulta de NF-e (product_invoice_query) no SDK Ruby da NFE.io
sidebar_label: Consulta de NF-e
sidebar_position: 17
slug: consulta-nfe
description: Consulta de NF-e por chave de acesso — detalhes, download de PDF (DANFE) e XML, e listagem de eventos — no SDK Ruby da NFE.io.
---

# Consulta de NF-e (`product_invoice_query`)

O recurso `product_invoice_query` faz consultas somente-leitura de NF-e (nota
fiscal de produto) pela chave de acesso: detalhes, download de PDF (DANFE) e XML,
e listagem de eventos. Faz parte da família de **dados** `nfe_query`, servida por
`nfe.api.nfe.io`. O segmento de versão (`/v2`) já vem no caminho da requisição.

:::note Família de dados — configure `data_api_key`
Esta é uma família de **dados**: usa a `data_api_key` quando presente, com
**fallback** para a `api_key`. Configure `data_api_key:` (ou `NFE_DATA_API_KEY`).
Veja [Configuração](../configuration.md).
:::

## Métodos públicos

```ruby
product_invoice_query.retrieve(access_key)      # => Nfe::ProductInvoiceDetails | nil
product_invoice_query.download_pdf(access_key)  # => String (bytes ASCII-8BIT)
product_invoice_query.download_xml(access_key)  # => String (bytes ASCII-8BIT)
product_invoice_query.list_events(access_key)   # => Nfe::ProductInvoiceEventsResponse | nil
```

## Exemplos

### Consultar detalhes e eventos

```ruby
require "nfe"

client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: ENV.fetch("NFE_DATA_API_KEY")
)

chave = "35200114200166000187550010000000071234567890"

detalhes = client.product_invoice_query.retrieve(chave)
eventos  = client.product_invoice_query.list_events(chave)
```

:::warning Chave de acesso é validada antes do HTTP
A chave de acesso precisa ter **44 dígitos**. Uma chave inválida levanta
`Nfe::InvalidRequestError` **antes** de qualquer requisição. Veja
[Tratamento de erros](../errors.md).
:::

### Baixar PDF (DANFE) e XML

```ruby
pdf = client.product_invoice_query.download_pdf(chave)
File.binwrite("danfe.pdf", pdf)

xml = client.product_invoice_query.download_xml(chave)
File.binwrite("nfe.xml", xml)
```

:::tip Downloads retornam bytes binários
`download_pdf` e `download_xml` devolvem os **bytes** (`ASCII-8BIT`), não um
objeto hidratado. Grave-os com `File.binwrite`. Veja o guia de
[Downloads](../downloads.md).
:::

## Veja também

- [Consulta de NFC-e (consumer_invoice_query)](./consumer-invoice-query.md) — o equivalente para cupons.
- [Downloads](../downloads.md) — manipulação de PDF/XML binários.
- [Configuração](../configuration.md) — modelo de duas chaves.
