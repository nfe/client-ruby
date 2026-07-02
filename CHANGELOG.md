# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

## [1.0.0] - 2026-07-02

### Adicionado

- `Nfe::Client.new(api_key:)` — entrypoint por instância (estilo Stripe), com fallback de
  credencial via `ENV["NFE_API_KEY"]` / `ENV["NFE_DATA_API_KEY"]` (o argumento explícito vence).
- 19 acessores de recurso `snake_case` e lazy — 17 canônicos (`service_invoices`,
  `product_invoices`, `consumer_invoices`, `transportation_invoices`,
  `inbound_product_invoices`, `product_invoice_query`, `consumer_invoice_query`, `companies`,
  `legal_people`, `natural_people`, `webhooks`, `addresses`, `legal_entity_lookup`,
  `natural_person_lookup`, `tax_calculation`, `tax_codes`, `state_taxes`) mais 2 RTC
  (`service_invoices_rtc`, `product_invoices_rtc`).
- Modelos imutáveis `Data.define` gerados a partir das specs OpenAPI, com assinaturas RBS
  (`sig/**/*.rbs`) verificáveis pelo Steep e empacotadas na gem para type-check no consumidor.
- Contrato assíncrono 202 discriminado: `create` retorna um `*Pending`
  (`pending? -> true`/`issued? -> false`) ou um `*Issued` (`issued? -> true`); polling via
  `retrieve` até `Nfe::FlowStatus.terminal?(flow_status)`.
- Emissão RTC com tributos IBS/CBS/IS (`service_invoices_rtc`, `product_invoices_rtc`).
- Verificação de webhook HMAC-SHA1 sobre os bytes crus da requisição
  (`Nfe::Webhook.verify_signature`, comparação timing-safe, nunca levanta exceção) e
  `Nfe::Webhook.construct_event`.
- Roteamento multi-host automático por recurso (`api.nfe.io`, `api.nfse.io`,
  `address.api.nfe.io`, `legalentity.api.nfe.io`, `naturalperson.api.nfe.io`, `nfe.api.nfe.io`).
- Retry com backoff configurável (`max_retries`) para falhas transitórias.
- Downloads binários (String `ASCII-8BIT`) para a maioria dos recursos; exceção:
  `product_invoices` e `product_invoices_rtc` retornam `Nfe::NfeFileResource` (value object `{uri}`).
- `Nfe::DateNormalizer` para normalização consistente de datas.
- Modelo de duas chaves (`api_key` + `data_api_key`) com seleção automática por família de recurso.

### Alterado

- Namespace unificado em `Nfe`.
- Piso de Ruby elevado para **3.2+**.
- Paginação suporta os dois estilos da API: por página (`service_invoices`) e por cursor
  (`product`/`consumer`/`state_taxes`), via `Nfe::ListResponse`/`Nfe::ListPage`.
- Configuração migrada da API global para `Nfe::Client` por instância — ver `MIGRATION.md`.

### Removido

- Dependência de runtime `rest-client`.
- Configuração global `Nfe.api_key`.
- Classes achatadas da série `0.3.x` (ex.: `Nfe::ServiceInvoice.company_id(...).create`),
  preservadas no branch `0.x-legacy`.

## [0.3.2]

- Última versão da série `0.x` (legada, baseada em `rest-client`). Congelada, sem manutenção.

[Não lançado]: https://github.com/nfe/client-ruby/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/nfe/client-ruby/compare/v0.3.2...v1.0.0
[0.3.2]: https://github.com/nfe/client-ruby/releases/tag/v0.3.2
