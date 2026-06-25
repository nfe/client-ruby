# add-invoice-resources

## Why

`add-client-core` entregou o `Nfe::Client`, o transporte `Net::HTTP`, o roteamento multi-base-URL via `Nfe::Configuration`, a hierarquia de erros tipados, o contrato de resposta discriminada 202 (`Pending`/`Issued`) e os acessores lazy snake_case dos 17 recursos. Esta change preenche os **cinco recursos de invoice** — o coração da plataforma NFE.io — com implementações reais.

Quatro deles (service, product, transportation, inbound-product) são paritários 1:1 com o SDK Node.js em assinatura de método, ordem de parâmetros e categoria de retorno (modulo idiomas de linguagem: `Buffer` → `String` binário, `Promise`/async → retorno síncrono, `camelCase` → `snake_case`). O quinto (`consumer_invoices`, emissão NFC-e) é uma extensão **paridade-plus**: o SDK Node não expõe emissão de NFC-e, mas a API NFE.io a oferece nativamente desde a v2 via `nf-consumidor-v2.yaml`.

Esses recursos são o **primeiro consumidor real** dos blocos montados em `add-client-core`: exercitam o contrato 202 (`service_invoices.create` e `consumer_invoices.create`), validam o roteamento multi-host (CT-e/NF-e moram em `api.nfse.io`, NFS-e em `api.nfe.io`), e fecham a pipeline `OpenAPI → modelos gerados → recurso → client → transporte`.

> **Nota de escopo (RTC)**: a NOVA variante de emissão de NFS-e da Reforma Tributária (RTC, grupos IBS/CBS/IS) é tratada na change SEPARADA `add-rtc-invoice-emission`. Aqui implementamos a emissão **clássica** de service-invoice; o spec de RTC referencia esta change como base de padrões.

## What Changes

### Recursos implementados (5)

| Recurso (acessor) | Padrão | Host (família) | Operações principais |
|---|---|---|---|
| `client.service_invoices` | Emissão NFS-e (CRUD + downloads + status) | `api.nfe.io` (main) | `create` (202 discriminado), `list` (page-style), `retrieve`, `cancel`, `send_email`, `download_pdf`, `download_xml`, `get_status` |
| `client.product_invoices` | Emissão NF-e (CRUD + eventos + cartas de correção + inutilização) | `api.nfse.io` (cte) | `create`, `create_with_state_tax`, `list` (cursor), `retrieve`, `cancel`, `list_items`, `list_events`, `download_pdf/xml/rejection_xml/epec_xml`, `send_correction_letter`, `download_correction_letter_pdf/xml`, `disable`, `disable_range` |
| `client.consumer_invoices` ⭐ | Emissão NFC-e (paridade-plus, além do Node) | `api.nfse.io` (cte) | `create`, `create_with_state_tax`, `list` (cursor), `retrieve`, `cancel`, `list_items`, `list_events`, `download_pdf/xml/rejection_xml`, `disable_range` |
| `client.transportation_invoices` | Inbound CT-e (settings + consulta) | `api.nfse.io` (cte) | `enable`, `disable`, `get_settings`, `retrieve` (por accessKey), `download_xml`, `get_event`, `download_event_xml` |
| `client.inbound_product_invoices` | Inbound NF-e de fornecedores (settings + consulta + manifestação) | `api.nfse.io` (cte) | `enable_auto_fetch`, `disable_auto_fetch`, `get_settings`, `get_details`, `get_product_invoice_details`, `get_event_details`, `get_product_invoice_event_details`, `get_xml`, `get_event_xml`, `get_pdf`, `get_json`, `manifest`, `reprocess_webhook` |

> Host (família) `main` = `base_url_for(:main)` → `https://api.nfe.io`; o segmento `/v1` é fornecido pelo `api_version` do recurso (URL efetiva `https://api.nfe.io/v1/...`).

### Adicionado (suporte)

- `Nfe::Resources::ServiceInvoicePending` / `ServiceInvoiceIssued` — value objects `Data.define` para o contrato 202 de NFS-e (especialização concreta do contrato `Nfe::Pending`/`Nfe::Issued` de `add-client-core`).
- `Nfe::Resources::ProductInvoicePending` / `ProductInvoiceIssued`.
- `Nfe::Resources::ConsumerInvoicePending` / `ConsumerInvoiceIssued`.
- `Nfe::NfeFileResource` — value object `Data.define` que carrega a URI de download retornada por `product_invoices.download_*` (não bytes).
- DTOs de invoice hand-written sob `lib/nfe/resources/dto/` (ex.: `service_invoice.rb`, `consumer_invoice.rb`) onde o gerador OpenAPI não cobre o shape de resposta.

- Idempotência + opções por chamada na emissão: `create`/`create_with_state_tax` de service/product/consumer aceitam `idempotency_key:` (enviado como header `Idempotency-Key`; retry seguro reutiliza a MESMA chave para não duplicar documento fiscal) e `request_options:` (`Nfe::RequestOptions` de `add-client-core`, override de api_key/base_url/timeout por chamada). Vide design D13.

> Esta change **consome** (não redefine) as abstrações compartilhadas de `add-client-core`: `Nfe::IdValidator` (validação fail-fast de `company_id`/`invoice_id`/`access_key`/`state_tax_id`/`event_key`, levantando `Nfe::InvalidRequestError` em pt-BR), `Nfe::ListResponse`/`Nfe::ListPage` (os dois shapes de paginação), `Nfe::FlowStatus.terminal?`, e o helper de download binário de `Nfe::Resources::AbstractResource#download` (retorna `String` em `ASCII-8BIT`).

### Diferenças de superfície NFC-e × NF-e (paridade-plus)

`consumer_invoices` **NÃO** replica três métodos de `product_invoices`, por imposição da legislação fiscal brasileira (não por limitação do SDK):

- `send_correction_letter` (CC-e) — carta de correção é instrumento fiscal apenas do NF-e.
- `download_epec_xml` — EPEC (Evento Prévio de Emissão em Contingência) só existe para NF-e.
- `disable` por invoice — NFC-e suporta apenas inutilização coletiva via `disable_range`.

### Divergência de retorno de download (product_invoices)

`product_invoices.download_pdf/xml/rejection_xml/epec_xml` retornam um **`NfeFileResource` (uma URI)**, não bytes crus — diferente de `service_invoices`, `consumer_invoices` e dos recursos inbound, que retornam bytes. Isso é comportamento da API e está documentado no spec.

### Fora de escopo (diferido)

- `create_and_wait` — helper de polling síncrono. Diferido (alinhado com `add-client-core`); o caller escreve loop manual com `FlowStatus.terminal?`.
- `create_batch` — açúcar concorrente; sem ganho real no modelo síncrono do SDK; diferido para release futura.
- Emissão RTC (IBS/CBS/IS) — coberta por `add-rtc-invoice-emission`.

## Capabilities

### New Capabilities
- `invoice-resources`: 5 recursos de invoice + classes de resposta discriminada por família (`*Pending`/`*Issued`) + `Nfe::NfeFileResource` + DTOs hand-written de invoice. Consome (não redefine) `Nfe::IdValidator`, `Nfe::ListResponse`/`Nfe::ListPage`, `Nfe::FlowStatus.terminal?` e os helpers de `Nfe::Resources::AbstractResource`, todos de `add-client-core`.

### Modified Capabilities
- Nenhuma. Esta change apenas **consome** os contratos definidos em `add-client-core` (host map, contrato 202, acessores lazy, erros tipados); não os modifica.

## Impact

- **Affected code**:
  - `lib/nfe/resources/service_invoices.rb`, `product_invoices.rb`, `consumer_invoices.rb`, `transportation_invoices.rb`, `inbound_product_invoices.rb` (substituem os stubs de `add-client-core`; herdam de `Nfe::Resources::AbstractResource`).
  - `lib/nfe/resources/service_invoice_pending.rb`, `service_invoice_issued.rb`, e equivalentes product/consumer.
  - `lib/nfe/resources/dto/nfe_file_resource.rb` + DTOs hand-written de invoice (`service_invoice.rb`, `consumer_invoice.rb`, …).
  - `sig/nfe/resources/*.rbs` + `sig/nfe/resources/dto/*.rbs` (assinaturas RBS para Steep).
  - `spec/nfe/resources/*_spec.rb` + `spec/nfe/models/*_spec.rb` (RSpec com WebMock).
- **Spec impact**: adiciona o capability `invoice-resources`. Não modifica nenhum capability existente.
- **Dependencies**: depende de `add-client-core` (transporte, `Configuration` com host map, erros, contrato `Pending`/`Issued`, acessores lazy). Cruza com `add-rtc-invoice-emission` (variante RTC da emissão de service-invoice).
- **Risks**:
  - Envelopes de resposta (`{ serviceInvoices: [...] }`, `{ serviceInvoice: {...} }`) variam por endpoint — cada recurso desempacota o seu.
  - Paginação page-style × cursor-style — `ListPage` acomoda ambos; documentado por método.
  - `consumer_invoices` é paridade-plus sem referência cruzada no Node — smoke test em sandbox é essencial antes do GA.
  - `product_invoices.download_*` retorna URI, não bytes — divergência de contrato documentada para não confundir com os demais downloads.
