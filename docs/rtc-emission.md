---
title: Emissão RTC (Reforma Tributária do Consumo) no SDK Ruby da NFE.io
sidebar_label: Emissão RTC
sidebar_position: 9
description: Emita NFS-e e NF-e/NFC-e sob o layout da Reforma Tributária do Consumo com service_invoices_rtc e product_invoices_rtc — o layout é selecionado pela forma do payload (ibsCbs / items[].tax.IBSCBS), sem header discriminador.
---

# Emissão RTC

A **Reforma Tributária do Consumo (RTC)** introduz os novos grupos de imposto
(IBS, CBS e, para produtos, o Imposto Seletivo — IS). O SDK expõe a emissão RTC
de forma **opt-in**, por meio de dois recursos dedicados:

- `service_invoices_rtc` — NFS-e, host `api.nfe.io` (família `main`).
- `product_invoices_rtc` — NF-e (mod 55) e NFC-e (mod 65), host `api.nfse.io` (família `cte`).

Os recursos clássicos (`service_invoices` e `product_invoices`) permanecem
inalterados.

## O layout RTC é selecionado pela forma do payload

Os recursos RTC usam os **mesmos endpoints** e o mesmo fluxo dos recursos
clássicos. **Não existe header discriminador nem parâmetro de query**: a API
seleciona o layout RTC a partir da **presença** de um grupo no payload.

- NFS-e: presença do grupo `ibsCbs` na raiz do payload.
- Produto: presença do grupo a nível de item em `items[].tax.IBSCBS`.

Quando esses grupos estão ausentes, a API recai no layout clássico.

:::note `create(data:)` recebe um Hash
`create` recebe um **Hash** com chaves em **camelCase** (serializado como JSON
tal como está). Os DTOs gerados (`Nfe::Generated::ServiceInvoiceRtcV1::NFSeRequest`
e `Nfe::Generated::ProductInvoiceRtcV1::ProductInvoiceRequest`) **documentam a
forma** do payload, mas não são aceitos como entrada — eles apenas desserializam
respostas (`from_api`) e não têm caminho de re-serialização camelCase.
:::

## NFS-e RTC: o grupo `ibsCbs`

```ruby
result = client.service_invoices_rtc.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    cityServiceCode: "2690",
    federalServiceCode: "0107",
    description: "Manutenção e suporte técnico",
    servicesAmount: 100.0,
    nbsCode: "123456789",
    borrower: { federalTaxNumber: "191", name: "Banco do Brasil SA" },
    ibsCbs: {
      operationIndicator: "000000",
      classCode: "000001",
      cbs: { rate: 0.009, amount: 0.9 },
      ibs: {
        state: { rate: 0.001, amount: 0.1 },
        municipal: { rate: 0.0, amount: 0.0 }
      }
    }
  }
)
```

Dentro de `ibsCbs`, `operationIndicator` (6 dígitos, `^[0-9]{6}$`) e `classCode`
(até 6 caracteres) são obrigatórios.

## Produto RTC: `items[].tax.IBSCBS` e `IS`

No payload de produto, os grupos RTC ficam **a nível de item**, em `items[].tax`,
ao lado dos grupos legados. O `IBSCBS` divide o IBS em esfera estadual (`state`)
e municipal (`municipal`), com o `cbs` (federal) sem divisão. O grupo `IS`
(Imposto Seletivo) é **exclusivo do payload de produto** — não há equivalente na
NFS-e.

```ruby
result = client.product_invoices_rtc.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    printType: "Normal",
    items: [
      {
        code: "001",
        description: "Produto exemplo",
        quantity: 1,
        unitAmount: 100.0,
        tax: {
          IBSCBS: {
            state: { rate: 0.001, amount: 0.1 },
            municipal: { rate: 0.0, amount: 0.0 },
            cbs: { rate: 0.009, amount: 0.9 }
          },
          IS: {
            situationCode: "000",
            classificationCode: "000000",
            basis: 100.0,
            rate: 0.0,
            amount: 0.0
          }
        }
      }
    ]
  }
)
```

:::tip NF-e (mod 55) vs NFC-e (mod 65)
Os dois modelos são emitidos pelo mesmo `create` e pelo mesmo endpoint. A
distinção vem da **forma do payload** (`printType`, `consumerType`/`presenceType`,
presença de `buyer`, presença de `expectedDeliveryOn`) — nenhum discriminador de
`model`/`mod` é enviado na raiz da requisição.
:::

## Retorno discriminado e polling

Como na emissão clássica, `create` devolve **um de dois tipos**, distinguíveis
por pattern matching ou pelos predicados `pending?`/`issued?`. As classes RTC são
distintas das clássicas:

- NFS-e: `Nfe::Resources::ServiceInvoiceRtcPending` / `ServiceInvoiceRtcIssued`.
- Produto: `Nfe::Resources::ProductInvoiceRtcPending` / `ProductInvoiceRtcIssued`.

```ruby
case result
in Nfe::Resources::ServiceInvoiceRtcPending => pending
  pending.invoice_id   # reconsultar enquanto processa
in Nfe::Resources::ServiceInvoiceRtcIssued => issued
  issued.resource      # nota já materializada
end
```

Não existe `create_and_wait`/`create_batch` — faça polling com `retrieve` até um
estado terminal usando `Nfe::FlowStatus.terminal?`:

```ruby
company_id = "55df4dc6b6cd9007e4f13ee8"
invoice_id = result.pending? ? result.invoice_id : result.resource.id

loop do
  invoice = client.service_invoices_rtc.retrieve(
    company_id: company_id,
    invoice_id: invoice_id
  )
  break if Nfe::FlowStatus.terminal?(invoice.flow_status)

  sleep 2
end
```

:::note Downloads de produto continuam devolvendo uma URI
Os `download_*` de `product_invoices_rtc` retornam um `Nfe::NfeFileResource`
(URI), exatamente como o recurso clássico de produto. Veja [Downloads](./downloads.md).
:::

## Próximos passos

- [Primeiros passos](./getting-started.md) — emissão clássica e o contrato 202.
- [Downloads](./downloads.md) — bytes vs. `Nfe::NfeFileResource`.
- [Roteamento multi-host](./multi-host-routing.md) — os hosts `main` e `cte`.
- [Webhooks](./webhooks.md) — receba a conclusão por push.
