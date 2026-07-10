---
title: Primeiros passos com o SDK Ruby da NFE.io
sidebar_label: Primeiros passos
sidebar_position: 1
slug: primeiros-passos
description: Instale o gem nfe-io, crie um Nfe::Client, emita sua primeira NFS-e e acompanhe o processamento com polling.
---

# Primeiros passos

Este guia cobre a instalação, a criação do cliente e a emissão da sua primeira
nota fiscal de serviço (NFS-e), incluindo o acompanhamento do processamento.

## 1. Instale o gem

```ruby
# Gemfile
gem "nfe-io", "~> 1.0"
```

```sh
bundle install
# ou, sem editar o Gemfile:
bundle add nfe-io
```

:::note Requisitos
Ruby **3.2** ou superior. O SDK não tem dependências de runtime — apenas a
biblioteca padrão do Ruby.
:::

## 2. Crie um cliente

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))
```

A chave também pode vir da variável de ambiente `NFE_API_KEY` — o argumento
explícito sempre vence. Recursos de **dados** (CEP, CNPJ, CPF, consultas) usam
uma segunda chave, `data_api_key:`, com fallback para `api_key`. Todas as opções
estão em [Configuração](./configuration.md).

## 3. Emita uma NFS-e

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
```

:::tip Chaves em camelCase
O corpo (`data:`) usa as chaves em camelCase, exatamente como a API espera.
:::

## 4. Trate o retorno discriminado

A emissão é assíncrona. `create` devolve **um de dois tipos**, que você pode
distinguir com pattern matching ou com os predicados `pending?`/`issued?`:

```ruby
case result
in Nfe::Resources::ServiceInvoicePending => pending
  pending.invoice_id           # id para reconsultar enquanto processa
in Nfe::Resources::ServiceInvoiceIssued => issued
  issued.resource              # NFS-e já materializada (HTTP 201)
end
```

## 5. Acompanhe até um estado terminal (polling)

Não existe `create_and_wait` na `v1.x` — faça polling com `retrieve` até um
estado terminal, usando `Nfe::FlowStatus.terminal?`:

```ruby
company_id = "55df4dc6b6cd9007e4f13ee8"
invoice_id = result.pending? ? result.invoice_id : result.resource.id

loop do
  invoice = client.service_invoices.retrieve(
    company_id: company_id,
    invoice_id: invoice_id
  )
  break if Nfe::FlowStatus.terminal?(invoice.flow_status)

  sleep 2
end
```

:::warning Produção vs. teste
A separação **produção vs. teste (homologação)** é definida na configuração da
sua conta em [app.nfe.io](https://app.nfe.io) — **não** pela chave de API nem
pelo SDK. O argumento `environment:` do cliente está reservado para uso futuro.
:::

## Próximos passos

- [Configuração](./configuration.md) — todas as opções do cliente.
- [Emissão assíncrona e polling](./async-and-polling.md) — o contrato 202 em detalhe.
- [Tratamento de erros](./errors.md) — `rescue` por tipo.
- [Webhooks](./webhooks.md) — receba a conclusão por push em vez de polling.
