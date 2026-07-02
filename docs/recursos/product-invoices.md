---
title: Notas fiscais de produto (NF-e)
sidebar_label: Notas de produto
sidebar_position: 2
slug: notas-fiscais-de-produto
description: Emita NF-e modelo 55 com client.product_invoices no host api.nfse.io /v2 — listagem por cursor com environment obrigatório, carta de correção, inutilização e downloads por URI.
---

# Notas fiscais de produto (NF-e)

`client.product_invoices` cobre o ciclo de vida completo da NF-e (modelo 55) no
host `api.nfse.io`, sob `/v2`: emissão, listagem por cursor, consulta,
cancelamento, carta de correção (CC-e), inutilização e downloads.

A emissão segue o **contrato 202 discriminado** (assíncrona; conclusão via
webhook): `create` / `create_with_state_tax` devolvem `ProductInvoicePending`
ou `ProductInvoiceIssued`. Não há `create_and_wait` nem `create_batch`.

:::warning Downloads retornam URI, não bytes
Diferente das demais notas, os métodos de download desta classe retornam um
`Nfe::NfeFileResource` com o atributo `uri` — **não** os bytes do arquivo. Use a
`uri` para baixar o conteúdo separadamente.
:::

## Métodos

| Método | Descrição | Retorno |
|---|---|---|
| `create(company_id:, data:, idempotency_key: nil, request_options: nil)` | Emite a NF-e. | `ProductInvoicePending` ou `ProductInvoiceIssued` |
| `create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)` | Emite vinculada a uma inscrição estadual. | `ProductInvoicePending` ou `ProductInvoiceIssued` |
| `list(company_id:, environment:, **options)` | Lista por cursor; `environment` obrigatório. | `Nfe::ListResponse` |
| `retrieve(company_id:, invoice_id:)` | Consulta por id. | `Nfe::ProductInvoice` |
| `cancel(company_id:, invoice_id:, reason: nil)` | Cancela (assíncrono); `reason` vai na query. | `Hash` |
| `list_items(company_id:, invoice_id:, limit: nil, starting_after: nil)` | Lista os itens da nota. | `Nfe::ListResponse` |
| `list_events(company_id:, invoice_id:, limit: nil, starting_after: nil)` | Lista os eventos fiscais. | `Nfe::ListResponse` |
| `download_pdf(company_id:, invoice_id:, force: nil)` | DANFE PDF (URI). | `Nfe::NfeFileResource` |
| `download_xml(company_id:, invoice_id:)` | XML autorizado (URI). | `Nfe::NfeFileResource` |
| `download_rejection_xml(company_id:, invoice_id:)` | XML de rejeição (URI). | `Nfe::NfeFileResource` |
| `download_epec_xml(company_id:, invoice_id:)` | XML de contingência EPEC (URI). | `Nfe::NfeFileResource` |
| `send_correction_letter(company_id:, invoice_id:, reason:)` | Emite CC-e; `reason` de 15 a 1000 caracteres. | `Hash` |
| `download_correction_letter_pdf(company_id:, invoice_id:)` | PDF da CC-e (URI). | `Nfe::NfeFileResource` |
| `download_correction_letter_xml(company_id:, invoice_id:)` | XML da CC-e (URI). | `Nfe::NfeFileResource` |
| `disable(company_id:, invoice_id:, reason: nil)` | Inutiliza uma nota (assíncrono). | `Hash` |
| `disable_range(company_id:, data:)` | Inutiliza uma faixa de numeração. | `Hash` |

As opções de cursor em `list`, `list_items` e `list_events` são
`starting_after`, `ending_before`, `limit` e `q`.

## Emitir uma NF-e

```ruby
result = client.product_invoices.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    buyer: { federalTaxNumber: 11111111111111, name: "Cliente Exemplo LTDA" },
    items: [
      { code: "001", description: "Produto X", quantity: 1, unitAmount: 99.9 }
    ]
  }
)

if result.pending?
  result.invoice_id   # acompanhe via retrieve
else
  result.resource     # Nfe::ProductInvoice
end
```

:::tip Idempotência
Tanto `create` quanto `create_with_state_tax` aceitam `idempotency_key:` (header
`Idempotency-Key`) e `request_options:` (overrides por chamada). Em retentativas,
reutilize a **mesma** chave para evitar emissão duplicada.
:::

## Listar com `environment` obrigatório

A paginação é por cursor e o parâmetro `environment` (String `"Production"` ou
`"Test"`) é **obrigatório** — chamar `list` sem ele levanta
`Nfe::InvalidRequestError` sem chamada HTTP.

```ruby
pagina = client.product_invoices.list(
  company_id: company_id,
  environment: "Production",
  limit: 50
)
pagina.each { |nf| puts nf.id }
```

:::note `environment` é o ambiente da SEFAZ
Este `environment` (String) é um parâmetro real de ambiente da SEFAZ, separado
da configuração produção/teste da conta (definida em
[app.nfe.io](https://app.nfe.io)). O `environment:` (símbolo) do `Nfe::Client`
está reservado para uso futuro.
:::

## Acompanhar até um estado terminal

```ruby
loop do
  nf = client.product_invoices.retrieve(
    company_id: company_id,
    invoice_id: invoice_id
  )
  break if Nfe::FlowStatus.terminal?(nf.flow_status)

  sleep 2
end
```

## Baixar arquivos (via URI)

```ruby
arquivo = client.product_invoices.download_pdf(
  company_id: company_id,
  invoice_id: invoice_id
)
arquivo.uri   # URL para baixar o DANFE PDF
```

## Carta de correção (CC-e)

O `reason` precisa ter entre 15 e 1000 caracteres; fora dessa faixa o SDK
levanta `Nfe::InvalidRequestError` antes de qualquer HTTP.

```ruby
client.product_invoices.send_correction_letter(
  company_id: company_id,
  invoice_id: invoice_id,
  reason: "Correção do endereço de entrega do destinatário"
)
```

## Inutilizar (disablement)

```ruby
# Uma nota específica:
client.product_invoices.disable(
  company_id: company_id,
  invoice_id: invoice_id,
  reason: "Numeração não utilizada"
)

# Uma faixa de numeração:
client.product_invoices.disable_range(
  company_id: company_id,
  data: {
    environment: "Production", serie: 1, state: "SP",
    beginNumber: 100, lastNumber: 110, reason: "Falha de impressão"
  }
)
```

## Próximos passos

- [Notas de consumidor (NFC-e)](./consumer-invoices.md) — downloads em bytes.
- [Emissão RTC](./rtc.md) — `product_invoices_rtc` com IBS/CBS/IS no item.
- [Paginação](../pagination.md) — cursor vs. página.
