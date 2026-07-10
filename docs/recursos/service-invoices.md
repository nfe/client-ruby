---
title: Notas fiscais de serviço (NFS-e)
sidebar_label: Notas de serviço
sidebar_position: 1
slug: notas-fiscais-de-servico
description: Emita, liste, consulte, cancele e baixe NFS-e com client.service_invoices no host api.nfe.io /v1, tratando o retorno discriminado 202.
---

# Notas fiscais de serviço (NFS-e)

`client.service_invoices` é o recurso canônico de emissão da plataforma. Ele
fala com o host `api.nfe.io` no caminho `/v1` e cobre todo o ciclo de vida da
NFS-e: emissão assíncrona, listagem paginada, consulta, cancelamento, envio por
e-mail e download de PDF/XML.

A emissão segue o **contrato 202 discriminado**: `create` devolve um de dois
tipos, e você acompanha o processamento com `retrieve` (ou `get_status`) até um
estado terminal. Não existe `create_and_wait` nem `create_batch` na `v1.x`.

:::note Host e versão
Todas as URLs efetivas ficam sob `https://api.nfe.io/v1/...`. Este é o único
recurso de nota que usa o host `api.nfe.io`; os demais usam `api.nfse.io`.
:::

## Métodos

| Método | Descrição | Retorno |
|---|---|---|
| `create(company_id:, data:, idempotency_key: nil, request_options: nil)` | Emite a NFS-e. | `ServiceInvoicePending` ou `ServiceInvoiceIssued` |
| `list(company_id:, **options)` | Lista paginada (page-style) com filtros de data. | `Nfe::ListResponse` |
| `retrieve(company_id:, invoice_id:)` | Consulta uma NFS-e por id. | `Nfe::ServiceInvoice` |
| `cancel(company_id:, invoice_id:)` | Cancela (síncrono) e devolve o modelo atualizado. | `Nfe::ServiceInvoice` |
| `send_email(company_id:, invoice_id:)` | Reenvia a nota por e-mail ao tomador. | `Hash` com `sent:` e `message:` |
| `download_pdf(company_id:, invoice_id: nil)` | PDF da nota; sem `invoice_id`, baixa o ZIP da empresa. | `String` binária |
| `download_xml(company_id:, invoice_id: nil)` | XML da nota; sem `invoice_id`, baixa o ZIP da empresa. | `String` binária |
| `get_status(company_id:, invoice_id:)` | Snapshot de status derivado de `retrieve` (sem HTTP extra). | `StatusResult` |

As opções de `list` (em snake_case) são `page_index`, `page_count`,
`issued_begin`, `issued_end`, `created_begin`, `created_end` e `has_totals`.

:::warning Validação fail-fast
Todo método valida `company_id` e `invoice_id` via `Nfe::IdValidator` **antes**
de qualquer chamada HTTP. Ids vazios ou em branco levantam
`Nfe::InvalidRequestError` sem tráfego de rede.
:::

## Emitir uma NFS-e e tratar o retorno discriminado

`create` devolve `ServiceInvoicePending` (HTTP 202, enfileirada) ou
`ServiceInvoiceIssued` (HTTP 201, já materializada). Distinga por pattern
matching ou pelos predicados `pending?` / `issued?`.

```ruby
result = client.service_invoices.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    cityServiceCode: "2690",
    description: "Manutenção e suporte técnico",
    servicesAmount: 100.0,
    borrower: { federalTaxNumber: "191", name: "Banco do Brasil SA" }
  }
)

case result
in Nfe::Resources::ServiceInvoicePending => pending
  pending.invoice_id   # id para reconsultar enquanto processa
  pending.location     # caminho do header Location
in Nfe::Resources::ServiceInvoiceIssued => issued
  issued.resource      # Nfe::ServiceInvoice já emitida
end
```

:::tip Idempotência em retentativas
Passe `idempotency_key:` para enviar o header `Idempotency-Key`. O SDK nunca
refaz o POST sozinho; em um timeout, reinvoque `create` com a **mesma** chave
para o servidor deduplicar e não emitir documento fiscal duplicado.
:::

## Acompanhar até um estado terminal (polling)

Use `get_status`, que deriva o status de um único `retrieve` (sem chamada HTTP
adicional) e expõe `complete?` e `failed?`.

```ruby
company_id = "55df4dc6b6cd9007e4f13ee8"
invoice_id = result.pending? ? result.invoice_id : result.resource.id

loop do
  status = client.service_invoices.get_status(
    company_id: company_id,
    invoice_id: invoice_id
  )
  break if status.complete?   # via Nfe::FlowStatus.terminal?

  sleep 2
end
```

Como alternativa, você pode chamar `retrieve` diretamente e testar
`Nfe::FlowStatus.terminal?(invoice.flow_status)`.

## Ler os campos da nota (tipados + `raw`)

`Nfe::ServiceInvoice` tipa os campos de maior valor — incluindo o trio de ISS
`base_tax_amount`, `iss_rate` e `iss_tax_amount` — e preserva **o payload
completo** da API em `invoice.raw`. Campos sem membro tipado (a árvore de
retenções, `provider`, `taxationType`, `location`, `approximateTax`, ...)
ficam acessíveis por ali:

```ruby
invoice = client.service_invoices.retrieve(
  company_id: company_id,
  invoice_id: invoice_id
)

invoice.number            # número fiscal
invoice.iss_rate          # 0.05
invoice.iss_tax_amount    # 50.0

invoice.raw["taxationType"]           # "WithinCity"
invoice.raw["issAmountWithheld"]      # retenção de ISS
invoice.raw.dig("provider", "name")   # prestador (21 campos via raw)
```

O `borrower` (tomador) é um `Nfe::ServiceInvoiceBorrower` tipado, com
`federal_tax_number` sempre `String` (tolerante ao CNPJ alfanumérico da
IN RFB 2.229/2024). Leituras estilo Hash continuam funcionando (delegam ao
payload cru, chaves camelCase):

```ruby
invoice.borrower.name                  # tipado
invoice.borrower.federal_tax_number    # "191" (String, mesmo se o fio mandar Integer)
invoice.borrower["federalTaxNumber"]   # 191 (valor cru do fio)
invoice.borrower.dig("address", "city", "name")
```

:::warning `pdf` e `xml` estão deprecated
Os membros `invoice.pdf` e `invoice.xml` são campos-fantasma — a resposta do
retrieve não os traz (sempre `nil`). Use `download_pdf`/`download_xml`.
:::

## Baixar PDF e XML (bytes binários)

Os downloads retornam uma `String` binária (`ASCII-8BIT`) — grave com
`File.binwrite`. Omitir `invoice_id` baixa o ZIP de todas as notas da empresa.

```ruby
pdf = client.service_invoices.download_pdf(
  company_id: company_id,
  invoice_id: invoice_id
)
File.binwrite("nfse.pdf", pdf)

# ZIP de todas as notas da empresa (sem invoice_id):
zip = client.service_invoices.download_xml(company_id: company_id)
File.binwrite("notas.zip", zip)
```

## Cancelar e reenviar por e-mail

```ruby
cancelada = client.service_invoices.cancel(
  company_id: company_id,
  invoice_id: invoice_id
)
cancelada.flow_status   # "Cancelled"

envio = client.service_invoices.send_email(
  company_id: company_id,
  invoice_id: invoice_id
)
envio[:sent]   # true/false
```

## Próximos passos

- [Primeiros passos](../getting-started.md) — instalação e primeira emissão.
- [Notas de produto (NF-e)](./product-invoices.md) — host `api.nfse.io` e downloads por URI.
- [Emissão RTC](./rtc.md) — layout da Reforma Tributária.
