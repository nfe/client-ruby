---
title: Emissão RTC (Reforma Tributária — IBS, CBS e IS)
sidebar_label: Emissão RTC
sidebar_position: 6
description: Emita NFS-e e NF-e/NFC-e no layout da Reforma Tributária do Consumo com client.service_invoices_rtc (api.nfe.io /v1) e client.product_invoices_rtc (api.nfse.io /v2), selecionando o layout pela presença dos grupos IBS/CBS no payload.
---

# Emissão RTC (Reforma Tributária do Consumo)

A Reforma Tributária do Consumo (RTC) adiciona os grupos de tributos IBS, CBS e
IS aos documentos fiscais. O SDK expõe dois recursos dedicados e **opt-in** para
emitir no layout RTC, sem alterar os recursos clássicos:

- `client.service_invoices_rtc` — NFS-e RTC, host `api.nfe.io` sob `/v1`.
- `client.product_invoices_rtc` — NF-e (mod 55) e NFC-e (mod 65) RTC, host `api.nfse.io` sob `/v2`.

Ambos reutilizam os **mesmos endpoints** dos recursos clássicos. Não há header
nem parâmetro de discriminação: o layout RTC é selecionado pela **presença dos
grupos de imposto no payload**.

:::note O que seleciona o layout RTC
- Em serviço: o grupo `ibsCbs` na raiz do payload (camelCase).
- Em produto: o grupo `IBSCBS` no nível do item (`items[].tax.IBSCBS`).

Quando esses grupos estão ausentes, a API usa o layout clássico.
:::

:::tip `data:` é sempre um Hash em camelCase
Em ambos os recursos, `create(data:)` recebe um **Hash** com chaves camelCase,
serializado como está. As DTOs geradas (`Nfe::Generated::ServiceInvoiceRtcV1` e
`Nfe::Generated::ProductInvoiceRtcV1`) documentam a **forma** esperada do
payload, mas só desserializam respostas — não são aceitas como entrada.
:::

Consulte o guia conceitual em [Emissão RTC](../rtc-emission.md) para o contexto
fiscal completo.

---

## NFS-e RTC — `client.service_invoices_rtc`

Host `api.nfe.io` sob `/v1`, mesmo host do `client.service_invoices` clássico.

### Métodos

| Método | Descrição | Retorno |
|---|---|---|
| `create(company_id:, data:, idempotency_key: nil, request_options: nil)` | Emite a NFS-e RTC. | `ServiceInvoiceRtcPending` ou `ServiceInvoiceRtcIssued` |
| `retrieve(company_id:, invoice_id:)` | Consulta por id. | `Nfe::ServiceInvoice` |
| `cancel(company_id:, invoice_id:)` | Cancela (síncrono). | `Nfe::ServiceInvoice` |
| `download_cancellation_xml(company_id:, invoice_id:)` | XML do evento de cancelamento (e110001). | `String` binária |

### Emitir uma NFS-e RTC

O grupo `ibsCbs` (com `operationIndicator` e `classCode`) seleciona o layout.

```ruby
result = client.service_invoices_rtc.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    borrower: { federalTaxNumber: "191", name: "Banco do Brasil SA" },
    cityServiceCode: "2690",
    federalServiceCode: "01.01",
    description: "Consultoria",
    servicesAmount: 100.0,
    nbsCode: "1.0101",
    ibsCbs: {
      operationIndicator: "000000",
      classCode: "000001",
      cbs: { rate: 0.088, amount: 8.8 },
      ibs: { state: { rate: 0.177, amount: 17.7 }, municipal: { rate: 0.0, amount: 0.0 } }
    }
  }
)

if result.is_a?(Nfe::Resources::ServiceInvoiceRtcPending)
  result.invoice_id   # acompanhe via retrieve
else
  result.resource     # Nfe::ServiceInvoice
end
```

:::warning Cancellation XML é apenas do Ambiente Nacional
`download_cancellation_xml` só está disponível para notas do Ambiente Nacional
(ADN) e depois que a nota atinge o status `Cancelled`. Provedores
municipais/ABRASF não têm esse evento; nesse caso a API responde 404 e o SDK
levanta `Nfe::NotFoundError`.
:::

### Acompanhar até um estado terminal

```ruby
loop do
  nf = client.service_invoices_rtc.retrieve(
    company_id: company_id,
    invoice_id: invoice_id
  )
  break if Nfe::FlowStatus.terminal?(nf.flow_status)

  sleep 2
end
```

---

## NF-e / NFC-e RTC — `client.product_invoices_rtc`

Host `api.nfse.io` sob `/v2`, mesmo host do `client.product_invoices` clássico.
Um único `create` emite tanto NF-e (mod 55) quanto NFC-e (mod 65) — a distinção
vem da forma do payload (`printType`, `consumerType`/`presenceType`, presença de
`buyer`).

### Métodos

| Método | Descrição | Retorno |
|---|---|---|
| `create(company_id:, data:, idempotency_key: nil, request_options: nil)` | Emite a NF-e/NFC-e RTC. | `ProductInvoiceRtcPending` ou `ProductInvoiceRtcIssued` |
| `create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)` | Emite vinculada a uma inscrição estadual. | `ProductInvoiceRtcPending` ou `ProductInvoiceRtcIssued` |
| `list(company_id:, environment:, starting_after: nil, ending_before: nil, limit: nil, q: nil)` | Lista por cursor; `environment` obrigatório. | `Nfe::ListResponse` |
| `retrieve(company_id:, invoice_id:)` | Consulta por id. | `InvoiceResource` |
| `cancel(company_id:, invoice_id:, reason: nil)` | Cancela (assíncrono). | `RequestCancellationResource` |
| `list_items(company_id:, invoice_id:)` | Lista os itens. | `InvoiceItemsResource` |
| `list_events(company_id:, invoice_id:)` | Lista os eventos. | `InvoiceEventsResource` |
| `download_pdf(company_id:, invoice_id:, force: false)` | DANFE PDF (URI). | `Nfe::NfeFileResource` |
| `download_xml(company_id:, invoice_id:)` | XML autorizado (URI). | `Nfe::NfeFileResource` |
| `download_rejection_xml(company_id:, invoice_id:)` | XML de rejeição (URI). | `Nfe::NfeFileResource` |
| `download_epec_xml(company_id:, invoice_id:)` | XML de contingência EPEC (URI). | `Nfe::NfeFileResource` |
| `send_correction_letter(company_id:, invoice_id:, reason:)` | Emite CC-e; `reason` de 15 a 1000 caracteres. | `RequestCancellationResource` |
| `download_correction_letter_pdf(company_id:, invoice_id:)` | PDF da CC-e (URI). | `Nfe::NfeFileResource` |
| `download_correction_letter_xml(company_id:, invoice_id:)` | XML da CC-e (URI). | `Nfe::NfeFileResource` |
| `disable(company_id:, invoice_id:, reason: nil)` | Inutiliza uma nota. | `DisablementResource` |
| `disable_range(company_id:, data:)` | Inutiliza uma faixa de numeração. | `DisablementResource` |

Os tipos `InvoiceResource`, `RequestCancellationResource`, `DisablementResource`
etc. pertencem a `Nfe::Generated::ProductInvoiceRtcV1`.

:::warning Downloads retornam URI, não bytes
Como no recurso clássico de produto, os downloads retornam um
`Nfe::NfeFileResource` (atributo `uri`), e não os bytes do arquivo.
:::

### Emitir uma NF-e RTC

O grupo `IBSCBS` no item (`items[].tax.IBSCBS`) seleciona o layout. O grupo `IS`
(Imposto Seletivo) existe apenas no payload de produto.

```ruby
result = client.product_invoices_rtc.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    buyer: { federalTaxNumber: 11111111111111, name: "Cliente Exemplo LTDA" },
    items: [
      {
        code: "001", description: "Produto X", quantity: 1, unitAmount: 100.0,
        tax: {
          IBSCBS: {
            state: { rate: 0.177, amount: 17.7 },
            municipal: { rate: 0.0, amount: 0.0 },
            cbs: { rate: 0.088, amount: 8.8 }
          },
          IS: {
            situationCode: "00", classificationCode: "000",
            basis: 100.0, rate: 0.0, amount: 0.0
          }
        }
      }
    ]
  }
)

if result.is_a?(Nfe::Resources::ProductInvoiceRtcPending)
  result.invoice_id
else
  result.resource   # Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource
end
```

### Listar com `environment` obrigatório

```ruby
pagina = client.product_invoices_rtc.list(
  company_id: company_id,
  environment: "Production",
  limit: 50
)
pagina.each { |nf| puts nf.flow_status }
```

:::note `environment` é o ambiente da SEFAZ
O `environment` (String `"Production"`/`"Test"`) é o ambiente real da SEFAZ,
separado da configuração produção/teste da conta em
[app.nfe.io](https://app.nfe.io). Omiti-lo levanta `Nfe::InvalidRequestError`
sem chamada HTTP.
:::

### Acompanhar até um estado terminal

```ruby
loop do
  nf = client.product_invoices_rtc.retrieve(
    company_id: company_id,
    invoice_id: invoice_id
  )
  break if Nfe::FlowStatus.terminal?(nf.flow_status)

  sleep 2
end
```

## Próximos passos

- [Emissão RTC (guia conceitual)](../rtc-emission.md) — IBS/CBS/IS em detalhe.
- [Notas de serviço](./service-invoices.md) e [Notas de produto](./product-invoices.md) — os recursos clássicos.
