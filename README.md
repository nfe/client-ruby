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

# Emissão de NFS-e — o retorno é discriminado por tipo
result = client.service_invoices.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    city_service_code: "2690",
    description: "Manutenção e suporte técnico",
    services_amount: 100.0,
    borrower: { federal_tax_number: "191", name: "Banco do Brasil SA" }
  }
)

case result
in Nfe::Resources::ServiceInvoicePending => pending
  # HTTP 202 enfileirado — faça polling até um estado terminal
  # (não há create_and_wait/create_batch na v1.0).
  loop do
    status = client.service_invoices.get_status(
      company_id: "55df4dc6b6cd9007e4f13ee8", invoice_id: pending.invoice_id
    )
    break if status.complete?

    sleep 2
  end
in Nfe::Resources::ServiceInvoiceIssued => issued
  issued.resource # NFS-e já materializada (HTTP 201)
end
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
| **Consulta / dados** | `product_invoice_query` (NF-e por chave), `consumer_invoice_query` (cupom NFC-e por chave), `addresses` (CEP), `legal_entity_lookup` (CNPJ), `natural_person_lookup` (CPF), `tax_calculation` (motor de impostos), `tax_codes`, `state_taxes` (CRUD) |

Emissão no layout da **Reforma Tributária (RTC)** é opt-in via
`service_invoices_rtc` (NFS-e) e `product_invoices_rtc` (NF-e/NFC-e) — **mesmos
endpoints e mesmo fluxo discriminado/polling** do clássico. O leiaute RTC é
selecionado pela presença do grupo `ibsCbs` (NFS-e) ou `items[].tax.IBSCBS`
(produto) no payload — sem header/parâmetro discriminador.

```ruby
result = client.product_invoices_rtc.create(
  company_id: "co_1",
  data: {
    items: [{
      description: "Produto",
      tax: { IBSCBS: { situationCode: "000", classCode: "000001" } }
    }],
    payment: { ... }
  }
)
# Retorno discriminado (ProductInvoiceRtcPending | ProductInvoiceRtcIssued);
# faça polling com client.product_invoices_rtc.retrieve até
# Nfe::FlowStatus.terminal?(invoice.flow_status). O clássico continua disponível.
```

> **Roteamento multi-host**: cada família resolve seu próprio host — entidades e
> NFS-e em `api.nfe.io`; NF-e/NFC-e/CT-e e impostos em `api.nfse.io`; e os dados
> em hosts dedicados (`address.api.nfe.io`, `legalentity.api.nfe.io`,
> `naturalperson.api.nfe.io`, `nfe.api.nfe.io`). As quatro famílias de **dados
> dedicadas** usam a `data_api_key` (com fallback para `api_key`).

> **Não confundir**: `consumer_invoice_query` **consulta** um cupom NFC-e já
> emitido por chave de acesso (host `nfe.api.nfe.io`); `consumer_invoices`
> **emite** NFC-e (host `api.nfse.io`). Hosts e versões distintos.

> A v1 cobre **emissão** (clássica + **RTC**), **entidades** e **consulta/dados**
> — 19 acessores (17 canônicos + 2 addons RTC).

> **Downloads**: `product_invoices.download_*` devolve um `Nfe::NfeFileResource`
> (URI do arquivo), enquanto `service_invoices`, `consumer_invoices` e
> `transportation_invoices` devolvem os **bytes** do documento.
> `consumer_invoices` (NFC-e) segue a paridade-plus do SDK Node. Sem
> `create_and_wait`/`create_batch` na v1.0 — use o loop de polling com
> `Nfe::FlowStatus.terminal?` mostrado acima.

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
