---
title: Emissão assíncrona e polling no SDK Ruby da NFE.io
sidebar_label: Assíncrono e polling
sidebar_position: 3
slug: emissao-assincrona-e-polling
description: Entenda o contrato HTTP 202, os resultados Pending e Issued, o pattern matching com pending?/issued? e como montar um loop de polling com FlowStatus.terminal?.
---

# Emissão assíncrona e polling

A emissão de documentos fiscais é, em geral, **assíncrona**: a API aceita a
requisição (HTTP 202) e segue processando. Esta página explica o contrato de
retorno, os dois tipos de resultado e como acompanhar o processamento até um
estado terminal.

## O contrato HTTP 202

Quando a API responde **202 Accepted**, o documento ainda **não** foi
materializado — ela apenas aceitou o pedido. Quando responde **201/200**, o
documento já está pronto. O `create` traduz isso em um **resultado discriminado**:
um de dois tipos.

| Resposta HTTP | Tipo de resultado | Significado |
| --- | --- | --- |
| 202 Accepted | `Nfe::*Pending` | Em processamento; reconsulte depois. |
| 201 / 200 | `Nfe::*Issued` | Documento já materializado. |

:::note `*Pending` e `*Issued` por recurso
Cada recurso expõe seu par de resultados (por exemplo,
`Nfe::Resources::ServiceInvoicePending` e `Nfe::Resources::ServiceInvoiceIssued`).
O tipo base `Nfe::Pending` carrega `invoice_id` e `location`; o `Nfe::Issued`
carrega `resource`.
:::

## Os dois tipos de resultado

### `*Pending` (202)

- `#invoice_id` — id extraído do último segmento do header `Location`; use-o para
  reconsultar enquanto processa.
- `#location` — o valor bruto do header `Location`.
- `#pending?` → `true`.

### `*Issued` (201/200)

- `#resource` — o documento já materializado (DTO hidratado).
- `#issued?` → `true`.

## Distinguindo o resultado

Você pode discriminar com os predicados `pending?` / `issued?` ou com pattern
matching:

```ruby
result = client.service_invoices.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: { cityServiceCode: "2690", servicesAmount: 100.0, description: "Suporte" }
)

case result
in Nfe::Resources::ServiceInvoicePending => pending
  pending.invoice_id    # reconsulte com este id
in Nfe::Resources::ServiceInvoiceIssued => issued
  issued.resource       # NFS-e já pronta
end
```

Com predicados:

```ruby
invoice_id = result.pending? ? result.invoice_id : result.resource.id
```

## Loop de polling manual

Faça polling com `retrieve` até um **estado terminal**, decidido por
`Nfe::FlowStatus.terminal?`:

```ruby
company_id = "55df4dc6b6cd9007e4f13ee8"
invoice_id = result.pending? ? result.invoice_id : result.resource.id

invoice =
  loop do
    current = client.service_invoices.retrieve(
      company_id: company_id,
      invoice_id: invoice_id
    )
    break current if Nfe::FlowStatus.terminal?(current.flow_status)

    sleep 2
  end

# `invoice.flow_status` agora é um estado terminal.
```

### Estados de fluxo (`flow_status`)

Estados **terminais** (encerram o polling):

| Status | Significado |
| --- | --- |
| `Issued` | Emitido com sucesso. |
| `IssueFailed` | Falha na emissão. |
| `Cancelled` | Cancelado. |
| `CancelFailed` | Falha no cancelamento. |

`Nfe::FlowStatus.terminal?` aceita `String` ou `Symbol` e retorna `true` apenas
para os quatro acima; qualquer outro valor (como `WaitingSend` ou
`PullFromCityHall`) retorna `false`.

:::tip `get_status` em `service_invoices`
O recurso `service_invoices` oferece `get_status`, derivado do `retrieve` (sem
HTTP extra), como atalho para inspecionar o estado atual.
:::

## Por que não existe `create_and_wait`?

A `v1.x` **não** implementa `create_and_wait`, `create_batch` nem
`poll_until_complete`. O contrato discriminado `*Pending` / `*Issued` somado a
`Nfe::FlowStatus.terminal?` é suficiente para escrever loops de polling manuais,
e esses auxiliares ficam deliberadamente adiados para uma versão futura — sem
quebrar o contrato público.

:::warning Não chame helpers inexistentes
Referenciar `client.poll_until_complete(...)` ou `resource.create_and_wait(...)`
na `v1.x` levanta `NoMethodError`, pois o método não está definido.
:::

## Próximos passos

- [Tratamento de erros](./errors.md) — trate falhas durante o polling.
- [Configuração](./configuration.md) — ajuste `timeout` e `max_retries`.
- [Primeiros passos](./getting-started.md) — a primeira emissão de ponta a ponta.
