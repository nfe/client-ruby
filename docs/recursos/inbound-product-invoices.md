---
title: NF-e de entrada e manifestação do destinatário
sidebar_label: NF-e de entrada
sidebar_position: 5
slug: notas-de-entrada
description: Habilite a busca automática de NF-e de fornecedores (Distribuição DFe), leia documentos e eventos por chave de acesso e envie a manifestação do destinatário com client.inbound_product_invoices no host api.nfse.io /v2.
---

# NF-e de entrada e manifestação do destinatário

`client.inbound_product_invoices` gerencia NF-e **emitidas por fornecedores**
(entrada), no host `api.nfse.io`, sob `/v2`. Ele habilita a busca automática via
SEFAZ Distribuição DFe, lê documentos e eventos por chave de acesso, envia a
Manifestação do Destinatário e reprocessa webhooks.

:::note Recurso de entrada, não de emissão
É um recurso de consulta/configuração; não há contrato 202 `Pending` / `Issued`.
Existem duas superfícies de detalhe: o formato webhook-v1
(`.../inbound/{chave}`) e o formato webhook-v2 recomendado
(`.../inbound/productinvoice/{chave}`, que adiciona o array de NF-e de produto).
:::

## Métodos

| Método | Descrição | Retorno |
|---|---|---|
| `enable_auto_fetch(company_id:, **opts)` | Habilita a busca automática de NF-e. | `Nfe::InboundSettings` |
| `disable_auto_fetch(company_id:)` | Desabilita a busca automática. | `Nfe::InboundSettings` |
| `get_settings(company_id:)` | Lê as configurações atuais. | `Nfe::InboundSettings` |
| `get_details(company_id:, access_key:)` | Detalhes (webhook-v1). | `Nfe::InboundInvoiceMetadata` |
| `get_product_invoice_details(company_id:, access_key:)` | Detalhes da NF-e (webhook-v2). | `Nfe::InboundInvoiceMetadata` |
| `get_event_details(company_id:, access_key:, event_key:)` | Detalhes de um evento (webhook-v1). | `Nfe::InboundInvoiceMetadata` |
| `get_product_invoice_event_details(company_id:, access_key:, event_key:)` | Detalhes de um evento (webhook-v2). | `Nfe::InboundInvoiceMetadata` |
| `get_xml(company_id:, access_key:)` | XML do documento. | `String` binária |
| `get_event_xml(company_id:, access_key:, event_key:)` | XML de um evento. | `String` binária |
| `get_pdf(company_id:, access_key:)` | DANFE PDF da NF-e. | `String` binária |
| `get_json(company_id:, access_key:)` | Representação JSON estruturada. | `Nfe::InboundInvoiceMetadata` |
| `manifest(company_id:, access_key:, tp_event: 210210)` | Envia a manifestação do destinatário. | `String` |
| `reprocess_webhook(company_id:, access_key_or_nsu:)` | Reprocessa o webhook por chave ou NSU. | `Nfe::InboundInvoiceMetadata` |

As opções de `enable_auto_fetch` são `start_from_nsu`, `start_from_date`,
`environment_sefaz`, `automatic_manifesting` e `webhook_version`.

:::tip Constantes de tipo de evento da manifestação
O módulo expõe constantes para `tp_event`:

```ruby
Nfe::Resources::InboundProductInvoices::MANIFEST_AWARENESS      # 210210 (padrão) — Ciência da Operação
Nfe::Resources::InboundProductInvoices::MANIFEST_CONFIRMATION   # 210220 — Confirmação da Operação
Nfe::Resources::InboundProductInvoices::MANIFEST_NOT_PERFORMED  # 210240 — Operação não Realizada
```
:::

## Habilitar a busca automática

```ruby
settings = client.inbound_product_invoices.enable_auto_fetch(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  start_from_date: "2026-01-01",
  webhook_version: "2"
)
```

## Ler uma NF-e de fornecedor

```ruby
access_key = "35240611111111000199550010000012341000012345"

detalhes = client.inbound_product_invoices.get_product_invoice_details(
  company_id: company_id,
  access_key: access_key
)

pdf = client.inbound_product_invoices.get_pdf(
  company_id: company_id,
  access_key: access_key
)
File.binwrite("nfe-entrada.pdf", pdf)   # bytes binários (ASCII-8BIT)
```

## Manifestar o destinatário

`tp_event` é numérico e default `210210` (Ciência da Operação). Use as
constantes para confirmar ou recusar a operação.

```ruby
# Ciência da operação (padrão):
client.inbound_product_invoices.manifest(
  company_id: company_id,
  access_key: access_key
)

# Confirmação da operação:
client.inbound_product_invoices.manifest(
  company_id: company_id,
  access_key: access_key,
  tp_event: Nfe::Resources::InboundProductInvoices::MANIFEST_CONFIRMATION
)
```

## Reprocessar webhook (por chave ou NSU)

`reprocess_webhook` aceita tanto uma chave de acesso de 44 dígitos quanto um NSU
numérico — um NSU não é rejeitado como chave inválida.

```ruby
client.inbound_product_invoices.reprocess_webhook(
  company_id: company_id,
  access_key_or_nsu: "123456"
)
```

## Próximos passos

- [CT-e de entrada](./transportation-invoices.md) — busca automática de CT-e.
- [Webhooks](../webhooks.md) — receba a chegada de novos documentos por push.
