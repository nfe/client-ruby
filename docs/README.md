---
title: Biblioteca NFE.io em Ruby para Emissão de Notas Fiscais (NFS-e, NF-e, NFC-e, CT-e)
description: SDK Ruby oficial da NFE.io — Ruby 3.2+, zero dependências de runtime, cliente estilo Stripe, tipos RBS e modelos imutáveis.
sidebar_label: Biblioteca Ruby
slug: /desenvolvedores/bibliotecas/ruby
provider: NFE.io
badge: SDK
layout_type: IntegrationLayout
heroImage: /docs/img/bibliotecas/ruby.svg
ctaLabel: GitHub NFE.io Ruby
ctaUrl: https://github.com/nfe/client-ruby
---

# Biblioteca Ruby NFE.io

SDK oficial da [NFE.io](https://nfe.io) para Ruby: emissão e gestão de documentos
fiscais eletrônicos brasileiros (NFS-e, NF-e, NFC-e, CT-e) com ergonomia estilo
Stripe e **zero dependências de runtime**.

- **Cliente único** `Nfe::Client` com acessores `snake_case` por recurso.
- **Tipado** — assinaturas RBS empacotadas no gem; type-check com Steep.
- **Modelos imutáveis** (`Data.define`) gerados das specs OpenAPI oficiais.

## Requisitos

- Ruby **3.2** ou superior.
- **Zero dependências de runtime** — apenas a biblioteca padrão do Ruby.

## Instalação

```ruby
# Gemfile
gem "nfe-io", "~> 1.0"
```

```sh
bundle install   # ou: gem install nfe-io
```

## Primeiros passos

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))

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

O fluxo completo (retorno discriminado + polling) está em
[Primeiros passos](./getting-started.md).

## Guias

| Guia | Conteúdo |
|---|---|
| [Primeiros passos](./getting-started.md) | Instalação, cliente, primeira emissão e polling. |
| [Configuração](./configuration.md) | Todas as opções, modelo de duas chaves, fallback de ENV, TLS/proxy. |
| [Emissão assíncrona e polling](./async-and-polling.md) | Contrato 202 `Pending`/`Issued` e o laço de polling com `FlowStatus`. |
| [Tratamento de erros](./errors.md) | Hierarquia `Nfe::Error` e padrões de `rescue`. |
| [Webhooks](./webhooks.md) | Verificação HMAC-SHA1 e idempotência/replay. |
| [Paginação](./pagination.md) | Estilos page e cursor; `ListResponse` enumerável. |
| [Downloads](./downloads.md) | Bytes binários vs. `NfeFileResource`. |
| [Roteamento multi-host](./multi-host-routing.md) | Os hosts por família de recurso. |
| [Emissão RTC](./rtc-emission.md) | IBS/CBS/IS; leiaute `ibsCbs`/`IBSCBS`. |
| [Cookbook por recurso](./recursos/) | Um exemplo por recurso (os 17 canônicos + RTC). |

## Referência da API

A referência completa de classes e métodos é gerada com **YARD** a partir do
código-fonte (e dos comentários YARD):

```sh
bundle exec rake doc   # gera docs/api/
```

A versão publicada fica em [`/api/ruby/`](https://nfe.io/api/ruby/) (HTML estático).

## Migração

Vindo da série `0.x`? Veja o [guia de migração](../MIGRATION.md) — a `v1.0` é uma
reescrita greenfield, sem camada de compatibilidade.
