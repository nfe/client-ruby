---
title: Roteamento multi-host no SDK Ruby da NFE.io
sidebar_label: Roteamento multi-host
sidebar_position: 8
description: Entenda como o SDK roteia cada recurso para o host correto (api.nfe.io, api.nfse.io e os hosts de dados), o modelo de duas chaves e o escape hatch base_url_overrides.
---

# Roteamento multi-host

A plataforma NFE.io expõe várias APIs em hosts diferentes. O SDK roteia cada
recurso **automaticamente** para o host certo — nenhum recurso hard-codeia uma
URL. Cada recurso declara uma **família** (`api_family`) e obtém seu host a
partir da `Nfe::Configuration`.

## Famílias, hosts e recursos

| Família | Host | Recursos |
| --- | --- | --- |
| `main` | `api.nfe.io` (`/v1`) | `service_invoices`, `service_invoices_rtc`, entidades (companies, legal/natural people), `webhooks` |
| `cte` | `api.nfse.io` (`/v2`) | `product_invoices`, `product_invoices_rtc`, `consumer_invoices`, `transportation_invoices`, `inbound_product_invoices`, `tax_calculation`, `tax_codes`, `state_taxes` |
| `addresses` | `address.api.nfe.io/v2` | consulta de endereços (CEP) |
| `legal-entity` | `legalentity.api.nfe.io` | consulta de pessoa jurídica (CNPJ) |
| `natural-person` | `naturalperson.api.nfe.io` | consulta de pessoa física (CPF) |
| `nfe-query` | `nfe.api.nfe.io` | `product_invoice_query`, `consumer_invoice_query` |

:::note O segmento de versão
Para a família `main`, o `/v1` é fornecido pelo `api_version` de cada recurso,
não pelo host. O host de `addresses` já embute o `/v2`.
:::

## Modelo de duas chaves

O SDK usa duas chaves de API. As **famílias de dados** preferem `data_api_key`
(com fallback para `api_key`); todas as outras famílias usam `api_key`.

As famílias de dados são:

- `addresses`
- `legal-entity`
- `natural-person`
- `nfe-query`

```ruby
client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: ENV.fetch("NFE_DATA_API_KEY")
)
```

Qualquer das chaves pode vir das variáveis de ambiente `NFE_API_KEY` /
`NFE_DATA_API_KEY` (o argumento explícito sempre vence).

:::warning `:cte` NÃO é família de dados
A família `:cte` (`api.nfse.io` — emissão de NF-e/NFC-e/CT-e + regras de imposto,
tax codes e state taxes) usa a **`api_key` principal**, e não a `data_api_key`.
Neste SDK a emissão é uma capacidade central, não uma consulta de dados. Isso é
uma **divergência deliberada do SDK Node** (que roteia `api.nfse.io` pela cadeia
de fallback da chave de dados).
:::

## Escape hatch: `base_url_overrides`

Para apontar uma família para outro host (ambiente de testes próprio, proxy,
mock), use `base_url_overrides:` na configuração. Um override por família vence
o host padrão:

```ruby
client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  base_url_overrides: {
    cte: "https://mock.local/nfse"
  }
)
```

Uma família desconhecida cai no host `main` como padrão seguro.

## Próximos passos

- [Downloads](./downloads.md) — por que `product_invoices` (host `cte`) devolve uma URI em vez de bytes.
- [Emissão RTC](./rtc-emission.md) — os recursos RTC e seus hosts.
- [Paginação](./pagination.md) — formas de paginação por família.
