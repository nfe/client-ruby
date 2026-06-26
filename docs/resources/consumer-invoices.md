---
title: Notas fiscais de consumidor (NFC-e)
sidebar_label: Notas de consumidor
sidebar_position: 3
description: Emita NFC-e (modelo 65) com client.consumer_invoices no host api.nfse.io /v2 — emissão discriminada, listagem por cursor, downloads em bytes e inutilização coletiva.
---

# Notas fiscais de consumidor (NFC-e)

`client.consumer_invoices` cobre o ciclo de vida da NFC-e (Nota Fiscal de
Consumidor Eletrônica, modelo 65) no host `api.nfse.io`, sob `/v2`. É útil para
integrações de PDV e e-commerce.

:::note Adição parity-plus
Este recurso vai além do SDK Node.js, que não expõe emissão de NFC-e. A API
NFE.io suporta o ciclo completo da NFC-e desde a v2.
:::

A emissão segue o **contrato 202 discriminado**: `create` /
`create_with_state_tax` devolvem `ConsumerInvoicePending` ou
`ConsumerInvoiceIssued`. Não há `create_and_wait` nem `create_batch`.

## Métodos

| Método | Descrição | Retorno |
|---|---|---|
| `create(company_id:, data:, idempotency_key: nil, request_options: nil)` | Emite a NFC-e. | `ConsumerInvoicePending` ou `ConsumerInvoiceIssued` |
| `create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)` | Emite vinculada a uma inscrição estadual. | `ConsumerInvoicePending` ou `ConsumerInvoiceIssued` |
| `list(company_id:, **options)` | Lista por cursor. | `Nfe::ListResponse` |
| `retrieve(company_id:, invoice_id:)` | Consulta por id. | `Nfe::ConsumerInvoice` |
| `cancel(company_id:, invoice_id:)` | Cancela (síncrono). | `Nfe::ConsumerInvoice` |
| `list_items(company_id:, invoice_id:)` | Lista os itens. | `Array` |
| `list_events(company_id:, invoice_id:)` | Lista os eventos. | `Array` |
| `download_pdf(company_id:, invoice_id:)` | DANFE NFC-e PDF. | `String` binária |
| `download_xml(company_id:, invoice_id:)` | XML autorizado. | `String` binária |
| `download_rejection_xml(company_id:, invoice_id:)` | XML de rejeição. | `String` binária |
| `disable_range(company_id:, data:)` | Inutilização coletiva de uma faixa. | `Hash` |

:::warning Métodos ausentes por lei fiscal
A NFC-e não tem carta de correção, EPEC, nem inutilização individual. Logo,
`send_correction_letter`, `download_epec_xml` e `disable` **não existem** neste
recurso — chamá-los levanta `NoMethodError`. Para inutilizar, use apenas
`disable_range` (coletiva).
:::

## Emitir uma NFC-e

```ruby
result = client.consumer_invoices.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    items: [
      { code: "001", description: "Café 250g", quantity: 2, unitAmount: 19.9 }
    ],
    payment: [{ method: "Cash", amount: 39.8 }]
  }
)

case result
in Nfe::Resources::ConsumerInvoicePending => pending
  pending.invoice_id
in Nfe::Resources::ConsumerInvoiceIssued => issued
  issued.resource   # Nfe::ConsumerInvoice
end
```

:::tip Idempotência
`create` e `create_with_state_tax` aceitam `idempotency_key:` (header
`Idempotency-Key`) e `request_options:`. Reutilize a mesma chave em retentativas
para evitar emissão duplicada.
:::

## Acompanhar até um estado terminal

```ruby
loop do
  nfce = client.consumer_invoices.retrieve(
    company_id: company_id,
    invoice_id: invoice_id
  )
  break if Nfe::FlowStatus.terminal?(nfce.flow_status)

  sleep 2
end
```

## Baixar PDF e XML (bytes binários)

Ao contrário das notas de produto, aqui os downloads retornam uma `String`
binária (`ASCII-8BIT`) — grave com `File.binwrite`.

```ruby
pdf = client.consumer_invoices.download_pdf(
  company_id: company_id,
  invoice_id: invoice_id
)
File.binwrite("danfe-nfce.pdf", pdf)
```

## Inutilização coletiva

```ruby
client.consumer_invoices.disable_range(
  company_id: company_id,
  data: {
    environment: "Production", serie: 1, state: "SP",
    beginNumber: 50, lastNumber: 60, reason: "Falha de comunicação com a SEFAZ"
  }
)
```

## Próximos passos

- [Notas de produto (NF-e)](./product-invoices.md) — modelo 55 com downloads por URI.
- [Emissão RTC](./rtc.md) — layout da Reforma Tributária para produto.
