# nfe-io — SDK Ruby oficial da NFE.io

[![CI](https://github.com/nfe/client-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/nfe/client-ruby/actions/workflows/ci.yml)

> ⚠️ **v1 em desenvolvimento.** A `v1.0.0` é uma reescrita greenfield, com quebra
> total de compatibilidade em relação à série `0.x`. A versão legada (`0.3.2`,
> baseada em `rest-client`) está **congelada** no branch [`0.x-legacy`](https://github.com/nfe/client-ruby/tree/0.x-legacy)
> e não recebe manutenção. Para fixá-la: `gem "nfe-io", "~> 0.3"`.

SDK oficial da [NFE.io](https://nfe.io) para Ruby — emissão e gestão de documentos
fiscais eletrônicos brasileiros (NFS-e, NF-e, NFC-e, CT-e).

- **Ruby 3.2+** (CI em 3.2, 3.3 e 3.4).
- **Zero dependências de runtime** — apenas a stdlib do Ruby (`net/http`, `json`, `openssl`, ...).
- **Ergonomia estilo Stripe** — um único `Nfe::Client` com acessores de recurso `snake_case`.
- **Tipado** — assinaturas RBS em `sig/`, type-check com Steep.
- **Modelos imutáveis** gerados a partir das specs OpenAPI da documentação oficial.

## Instalação

```ruby
# Gemfile
gem "nfe-io", "~> 1.0"
```

```sh
bundle install
```

## Uso

```ruby
require "nfe"

client = Nfe::Client.new(api_key: "sua-api-key")

# Emissão de NFS-e (exemplo projetado para a v1)
result = client.service_invoices.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    city_service_code: "2690",
    description: "Manutenção e suporte técnico",
    services_amount: 100.0,
    borrower: { federal_tax_number: "191", name: "Banco do Brasil SA" }
  }
)
```

> A configuração também aceita `data_api_key:`, `environment:` (`:production` |
> `:development`), `timeout:` e overrides de host. O `environment` seleciona a
> **chave**, não a URL.

## Recursos

A `v1` expõe **17 recursos** no `Nfe::Client`, organizados por família:

| Grupo | Acessores |
|---|---|
| **Entidades** (`api.nfe.io`) | `companies`, `legal_people`, `natural_people`, `webhooks` |
| **Emissão** | `service_invoices` (NFS-e), `product_invoices` (NF-e), `consumer_invoices` (NFC-e), `transportation_invoices` (CT-e inbound), `inbound_product_invoices` |
| **Consulta / dados** | `product_invoice_query`, `consumer_invoice_query`, `addresses`, `legal_entity_lookup`, `natural_person_lookup`, `tax_calculation`, `tax_codes`, `state_taxes` |

Emissão no layout da **Reforma Tributária (RTC)** é exposta opcionalmente via
`service_invoices_rtc` (NFS-e) e `product_invoices_rtc` (NF-e/NFC-e).

> Os corpos dos recursos são entregues nas etapas seguintes do desenvolvimento da
> v1; esta versão estabelece a fundação (gem, namespace, configuração, tooling e CI).

## Desenvolvimento

```sh
bin/setup            # instala dependências
bundle exec rspec    # testes (gate de cobertura SimpleCov >= 80%)
bundle exec rubocop  # lint
bundle exec steep check  # type-check
bundle exec rbs validate # valida as assinaturas
bundle exec rake     # spec + rubocop + steep + rbs
```

## Migração da `0.x`

Veja [`MIGRATION.md`](MIGRATION.md). Em resumo: a API global (`Nfe.api_key(...)`,
`Nfe::ServiceInvoice.create`) dá lugar a `Nfe::Client.new(api_key:)` +
`client.service_invoices.create`, sem `rest-client` e com value objects imutáveis.

## Licença

MIT. Veja [`LICENSE.txt`](LICENSE.txt).
