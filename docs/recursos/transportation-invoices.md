---
title: Conhecimentos de transporte recebidos (CT-e)
sidebar_label: CT-e de entrada
sidebar_position: 4
slug: conhecimentos-de-transporte
description: Habilite a busca automática de CT-e (Distribuição DFe) e leia documentos e eventos recebidos por chave de acesso com client.transportation_invoices no host api.nfse.io /v2.
---

# Conhecimentos de transporte recebidos (CT-e)

`client.transportation_invoices` gerencia CT-e (Conhecimento de Transporte
Eletrônico) **recebidos**, no host `api.nfse.io`, sob `/v2`. Ele habilita a
busca automática via SEFAZ Distribuição DFe e lê documentos e eventos por chave
de acesso de 44 dígitos.

:::note Recurso de entrada, não de emissão
Este é um recurso de consulta/configuração (settings + buscas por chave de
acesso). Não há contrato 202 `Pending` / `Issued` aqui — não se emite CT-e por
este recurso.
:::

## Métodos

| Método | Descrição | Retorno |
|---|---|---|
| `enable(company_id:, start_from_nsu: nil, start_from_date: nil)` | Habilita a busca automática de CT-e. | `Nfe::InboundSettings` |
| `disable(company_id:)` | Desabilita a busca automática. | `Nfe::InboundSettings` |
| `get_settings(company_id:)` | Lê as configurações atuais de busca. | `Nfe::InboundSettings` |
| `retrieve(company_id:, access_key:)` | Metadados do CT-e por chave de acesso. | `Nfe::InboundInvoiceMetadata` |
| `download_xml(company_id:, access_key:)` | XML do CT-e. | `String` binária |
| `get_event(company_id:, access_key:, event_key:)` | Metadados de um evento do CT-e. | `Nfe::InboundInvoiceMetadata` |
| `download_event_xml(company_id:, access_key:, event_key:)` | XML de um evento do CT-e. | `String` binária |

:::warning Chave de acesso normalizada
A `access_key` é normalizada por `Nfe::IdValidator.access_key`: separadores
(espaços, pontos, traços) são removidos e o valor precisa ter exatamente 44
dígitos. Caso contrário, o SDK levanta `Nfe::InvalidRequestError` antes de
qualquer chamada HTTP.
:::

## Habilitar a busca automática

```ruby
settings = client.transportation_invoices.enable(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  start_from_date: "2026-01-01"
)
settings   # Nfe::InboundSettings
```

`start_from_nsu` e `start_from_date` são opcionais; quando `nil`, são omitidos
do corpo da requisição.

## Ler um CT-e recebido por chave de acesso

```ruby
access_key = "35240611111111000199570010000012341000012345"

cte = client.transportation_invoices.retrieve(
  company_id: company_id,
  access_key: access_key
)

xml = client.transportation_invoices.download_xml(
  company_id: company_id,
  access_key: access_key
)
File.binwrite("cte.xml", xml)
```

## Consultar e baixar um evento

```ruby
evento = client.transportation_invoices.get_event(
  company_id: company_id,
  access_key: access_key,
  event_key: "35240611111111000199570010000012341000012345-110111-01"
)

xml = client.transportation_invoices.download_event_xml(
  company_id: company_id,
  access_key: access_key,
  event_key: evento.id
)
File.binwrite("cte-evento.xml", xml)
```

## Próximos passos

- [NF-e de entrada (manifestação)](./inbound-product-invoices.md) — ingestão de NF-e de fornecedores.
- [Webhooks](../webhooks.md) — receba notificações de novos documentos.
