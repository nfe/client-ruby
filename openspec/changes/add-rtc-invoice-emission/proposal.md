# add-rtc-invoice-emission

## Why

A **Reforma Tributária do Consumo (RTC)** introduz os novos tributos sobre consumo — **IBS** (Imposto sobre Bens e Serviços, dividido em esfera estadual e municipal), **CBS** (Contribuição sobre Bens e Serviços) e, exclusivamente para produto, o **IS** (Imposto Seletivo) — nos documentos fiscais eletrônicos. Para **NFS-e**, isso se materializa em um **novo grupo `ibsCbs`** (nível raiz) no payload de emissão; para **NF-e/NFC-e** (produto), em **novos grupos no nível do item** (`items[].tax.IBSCBS` e `items[].tax.IS`), com IBS dividido em esfera estadual (`state`) e municipal (`municipal`), CBS federal e Imposto Seletivo. Ambos carregam regras próprias de local de incidência, classificação tributária (`classCode`/`cClassTrib`), código de situação (CST) e mecanismos especiais (diferimento, redução, crédito presumido, compras governamentais, monofásico, transferência de crédito, estorno, ZFM).

A fonte da verdade (`nfeio-docs`) publica esses layouts como **duas** OpenAPIs dedicadas:
- `service-invoice-rtc-v1.yaml` — título "API de Emissão de NFS-e - RTC", host `https://api.nfe.io`, `version: v3`, snapshot `NT_2025.002_v1.30_RTC`, 18 schemas nomeados, incluindo `NFSeRequest` e `ibsCbs`.
- `product-invoice-rtc-v1.yaml` — título "API de Emissão de Nota Fiscal de Produto (NFe/NFCe) - RTC", host `https://api.nfse.io`, `version: v3`, snapshot `NT_2025.002_v1.30_RTC_NF-e_IBS_CBS_IS` (Leiaute NFe/NFCe RTC — Modelo 55 e 65), 140 schemas nomeados, incluindo `ProductInvoiceRequest`, `IBSCBSTaxResource`, `IBSStateTaxResource`, `IBSMunicipalTaxResource`, `CBSTaxResource` e `ISTaxResource`.

Conforme `docs/documentacao/reforma-tributaria/index.md`, **a RTC não cria uma API nova**: ela adiciona novos grupos de campos e novas versões de layout — **o fluxo de emissão continua o mesmo** e a seleção do leiaute RTC é feita pela **forma do payload** (presença do grupo `ibsCbs` na NFS-e; presença do grupo item-level `IBSCBS` na NF-e/NFC-e), sem header nem query param. NF-e (modelo 55) e NFC-e (modelo 65) compartilham **um único endpoint e uma única spec**; são distinguidas pela **forma do payload** (`printType`, `consumerType`/`presenceType`, presença ou não de `buyer`/`expectedDeliveryOn`), não por um campo discriminador nem por endpoints separados.

Esta change adiciona ao SDK Ruby v1 a emissão de **NFS-e** E de **NF-e/NFC-e** no layout RTC. Ela é **aditiva e opt-in**: surface em recursos dedicados `client.service_invoices_rtc` e `client.product_invoices_rtc`, deixando os recursos clássicos `client.service_invoices` e `client.product_invoices` (definidos em `add-invoice-resources`) **intactos**. Isso isola o churn regulatório do RTC (sujeito a Notas Técnicas) fora do caminho de emissão clássico, espelhando exatamente a separação que a própria documentação (specs RTC dedicadas) e o SDK Node de referência (`serviceInvoicesRtc` + `productInvoicesRtc`) adotam.

Depende de:
- **`add-client-core`** — possui e define as abstrações compartilhadas reusadas aqui: o contrato discriminado 202 (`Nfe::Pending`/`Nfe::Issued`), o helper `Nfe::FlowStatus.terminal?`, o `Nfe::IdValidator`, o `download` binário e o `hydrate_list`/`handle_async_response` do `Nfe::Resources::AbstractResource`, o `Nfe::ListResponse`/`Nfe::ListPage` e o host map / roteamento multi-base-URL. O `service_invoices_rtc` usa o host `main` → `base_url_for(:main)` retorna `https://api.nfe.io`, `/v1` via `api_version`, URL efetiva `https://api.nfe.io/v1/...`. O `product_invoices_rtc` usa o host `cte` (alias `:product_invoices`) → `base_url_for(:cte)` retorna `https://api.nfse.io`, `/v2` via `api_version`, URL efetiva `https://api.nfse.io/v2/...` — **mesmo host do `product_invoices` clássico**, sem nova base URL.
- **`add-invoice-resources`** — reusa as superfícies clássicas de service-invoice e product-invoice e seus padrões: os recursos `service_invoices` e `product_invoices` (que permanecem intactos) e os subtipos concretos `ServiceInvoicePending`/`ServiceInvoiceIssued` que servem de modelo para os equivalentes RTC, além da superfície de ciclo de vida do produto (retrieve/list/cancel/events/items/downloads/CC-e/inutilização) carregada por paridade.
- **`add-openapi-pipeline`** — o gerador sincroniza `service-invoice-rtc-v1.yaml` E `product-invoice-rtc-v1.yaml` a partir de `nfeio-docs` e emite os value objects imutáveis (`Data.define`) sob `lib/nfe/generated/` mais as assinaturas `.rbs` sob `sig/`. Os schemas nomeados das specs RTC (`NFSeRequest`/`ibsCbs`; `ProductInvoiceRequest`/`IBSCBSTaxResource`/`ISTaxResource`) geram tipos ricos, sem a derivação de `operations[...]` que a NFS-e clássica (`nf-servico-v1.yaml`, 0 component schemas) exige.

## What Changes

### Novos recursos (2)

| Recurso | Padrão | Host (família) | Operações |
|---|---|---|---|
| `client.service_invoices_rtc` | Emissão NFS-e RTC (IBS/CBS, nível raiz) | `https://api.nfe.io` (`main`); `/v1` via `api_version`, URL efetiva `https://api.nfe.io/v1/...` | `create` (202/201 discriminado), `retrieve`, `cancel`, `download_cancellation_xml` |
| `client.product_invoices_rtc` | Emissão NF-e/NFC-e RTC (IBS estadual+municipal, CBS, IS — nível do item) | `https://api.nfse.io` (`cte`, alias `:product_invoices`); `/v2` via `api_version`, URL efetiva `https://api.nfse.io/v2/...` | `create` (202/201 discriminado), `create_with_state_tax`, `retrieve`, `list`, `cancel`, `list_items`, `list_events`, `download_pdf`, `download_xml`, `download_rejection_xml`, `download_epec_xml`, `send_correction_letter`, `download_correction_letter_pdf`, `download_correction_letter_xml`, `disable`, `disable_range` |

#### `client.service_invoices_rtc` (NFS-e RTC)

- **`create(company_id:, data:, idempotency_key: nil, request_options: nil)`** — `POST /v1/companies/{company_id}/serviceinvoices` com corpo no formato `NFSeRequest` (grupo `ibsCbs` obrigando `operation_indicator` + `class_code`). Reusa o contrato discriminado 202: retorna `Nfe::Resources::ServiceInvoiceRtcPending` (HTTP 202 + header `Location`) ou `Nfe::Resources::ServiceInvoiceRtcIssued` (HTTP 201 + corpo materializado). Mesmo endpoint da NFS-e clássica — o servidor seleciona o leiaute RTC pela presença do `ibsCbs`. Aceita `idempotency_key:` opcional (enviado como header `Idempotency-Key` para retry seguro; POST NÃO é auto-retried pelo transport) e `request_options:` opcional (`Nfe::RequestOptions` de `add-client-core`, sobrepõe `api_key`/`base_url`/`timeout` por chamada).
- **`retrieve(company_id:, invoice_id:)`** — `GET /v1/companies/{company_id}/serviceinvoices/{invoice_id}` para polling manual via `Nfe::FlowStatus.terminal?`.
- **`cancel(company_id:, invoice_id:)`** — `DELETE` do invoice (síncrono).
- **`download_cancellation_xml(company_id:, invoice_id:)`** ⭐ — `GET /v1/companies/{company_id}/serviceinvoices/{invoice_id}/cancellation-xml`. Recurso **novo do RTC** (Release 2026.5): baixa o XML do **evento de cancelamento** (`e110001`), separado do XML de emissão. Disponível **apenas** no **Ambiente Nacional (ADN)** e só após status `Cancelled`; provedores municipais/ABRASF retornam 404. Retorna `String` binária (bytes crus, ASCII-8BIT).

#### `client.product_invoices_rtc` (NF-e/NFC-e RTC) ⭐ novo nesta expansão

- **`create(company_id:, data:, idempotency_key: nil, request_options: nil)`** — `POST /v2/companies/{company_id}/productinvoices` com corpo no formato `ProductInvoiceRequest` (única operação que a spec RTC de produto define; `operationId createProductInvoice`). Corpo carrega, no nível do item (`items[].tax`), os novos grupos `IBSCBS` (`IBSCBSTaxResource`, com `state`/`municipal`/`cbs`) e `IS` (`ISTaxResource`, Imposto Seletivo). NF-e (modelo 55) vs NFC-e (modelo 65) é distinguida pela forma do payload (`printType`, `consumerType`/`presenceType`, `buyer`, `expectedDeliveryOn`), não por discriminador. Emissão assíncrona: a spec documenta 201, mas a superfície clássica de produto trata o mesmo POST como 202-enfileirado — o recurso usa o contrato discriminado 202: retorna `Nfe::Resources::ProductInvoiceRtcPending` (202 + `Location`) ou `Nfe::Resources::ProductInvoiceRtcIssued` (201 + corpo). Aceita `idempotency_key:` opcional (header `Idempotency-Key`; POST não é auto-retried) e `request_options:` opcional (`Nfe::RequestOptions`, sobrepõe `api_key`/`base_url`/`timeout` por chamada).
- **`create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)`** — `POST /v2/companies/{company_id}/statetaxes/{state_tax_id}/productinvoices`; emite contra uma Inscrição Estadual específica. Mesmo corpo RTC e mesmos `idempotency_key:`/`request_options:` do `create`. Carregado da superfície clássica de produto por paridade.
- **`retrieve(company_id:, invoice_id:)`** — `GET /v2/companies/{company_id}/productinvoices/{invoice_id}`; hidrata `InvoiceResource`.
- **`list(company_id:, ...)`** — `GET /v2/companies/{company_id}/productinvoices`; `environment` obrigatório; paginação por cursor (`starting_after`/`ending_before`/`limit`/`q`) via `Nfe::ListResponse`/`Nfe::ListPage`.
- **`cancel(company_id:, invoice_id:, reason:)`** — `DELETE /v2/companies/{company_id}/productinvoices/{invoice_id}?reason=`; assíncrono (204-enfileirado); retorna `RequestCancellationResource` (`{account_id, company_id, product_invoice_id, reason}`).
- **`list_items(company_id:, invoice_id:)`** — `GET .../items` (`InvoiceItemsResource`).
- **`list_events(company_id:, invoice_id:)`** — `GET .../events` (`InvoiceEventsResource` de `ActivityResource`).
- **`download_pdf` / `download_xml` / `download_rejection_xml` / `download_epec_xml`** — `GET .../pdf?force=` (DANFE), `.../xml` (autorizado), `.../xml-rejection`, `.../xml-epec` (contingência EPEC). Cada um retorna `Nfe::Models::NfeFileResource` (uma URI), igual à superfície clássica `product_invoices` e ao schema `FileResource{uri}` de `nf-produto-v2.yaml` — não bytes crus.
- **`send_correction_letter(company_id:, invoice_id:, reason:)`** — `PUT .../correctionletter` (CC-e; `reason` 15–1000 chars, sem acentos/especiais; assíncrono).
- **`download_correction_letter_pdf` / `download_correction_letter_xml`** — `GET .../correctionletter/pdf` e `.../correctionletter/xml`; cada um retorna `Nfe::Models::NfeFileResource` (uma URI), igual à superfície clássica `product_invoices`.
- **`disable(company_id:, invoice_id:, reason:)`** — `POST .../disablement?reason=` (inutilização de uma nota; assíncrono).
- **`disable_range(company_id:, data:)`** — `POST /v2/companies/{company_id}/productinvoices/disablement` (inutilização de faixa de numeração; corpo `DisablementResource`).

> A spec RTC de produto define formalmente **apenas** o `create` (POST). Os demais métodos de ciclo de vida (retrieve/list/cancel/events/items/downloads/CC-e/inutilização) são carregados da superfície **clássica** `product_invoices` (mesmo host `api.nfse.io` e mesma base `/v2`) por paridade, dando ao recurso RTC um ciclo de vida completo — exatamente como o Node prevê layering por cima do `productInvoicesRtc.create`.

### DTOs gerados (pipeline)

- Sincronizar `service-invoice-rtc-v1.yaml` E `product-invoice-rtc-v1.yaml` para o set de specs do gerador.
- Emitir, sob `lib/nfe/generated/service_invoice_rtc_v1/`, os value objects `Data.define` dos 18 schemas nomeados da NFS-e RTC: `NFSeRequest`, `ibsCbs` (com `ibs`/`cbs`/`regularTaxation`/`presumedCredits`/`governmentPurchase`/`creditTransfer`/`thirdPartyReimbursements`), `addressDefinition`, `partyDefinition`, `serviceAmountDefinitions`, `approximateTax`, `deduction`, `benefit`, `suspension`, etc., mais `sig/` correspondente.
- Emitir, sob `lib/nfe/generated/product_invoice_rtc_v1/`, os value objects `Data.define` dos 140 schemas nomeados da NF-e/NFC-e RTC, incluindo: `ProductInvoiceRequest` (raiz; `required: items, payment`), `InvoiceResource`, `InvoiceWithoutEventsResource`, `ProductInvoicesResource`, `InvoiceItemResource`, `InvoiceItemTaxResource` (carrega `IS` + `IBSCBS`), `IBSCBSTaxResource`, `IBSStateTaxResource`, `IBSMunicipalTaxResource`, `CBSTaxResource`, `ISTaxResource`, `DefermentTaxResource`, `ReturnedTaxResource`, `ReductionTaxResource`, `RegularTaxationResource`, `GovernmentPurchaseTaxResource`, `MonophaseIBSCBSTaxResource`, `CreditTransferTaxResource`, `OperationalPresumedCreditResource`, `CreditReversalResource`, `ZfmPresumedCreditResource`, `CompetenceAdjustmentResource`, os totais (`IBSCBSTotalsResource`, `IBSTotalsResource`, `CBSTotalsResource`, `ISTotalsResource`, `Monophase*Totals`, `TotalsWithholdings`), os enums (`PrintType`, `OperationType`, `ConsumerType`, `ConsumerPresenceType`, `PurposeType`, `InvoiceStatus`), e `RequestCancellationResource`/`DisablementResource`/`FileResource`/`ErrorResource`/`ErrorsResource`, mais `sig/` correspondente.

### Classes de resposta (suporte)

- `Nfe::Resources::ServiceInvoiceRtcPending` (implementa o protocolo `Nfe::Pending` de `add-client-core`: `invoice_id`, `location`, predicados `pending?`/`issued?`).
- `Nfe::Resources::ServiceInvoiceRtcIssued` (implementa o protocolo `Nfe::Issued` de `add-client-core`: `resource` → DTO de service-invoice RTC; predicados `issued?`/`pending?`).
- `Nfe::Resources::ProductInvoiceRtcPending` (implementa `Nfe::Pending`: `invoice_id`, `location`, predicados `pending?`/`issued?`).
- `Nfe::Resources::ProductInvoiceRtcIssued` (implementa `Nfe::Issued`: `resource` → `Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource`; predicados `issued?`/`pending?`).

> Os predicados `pending?`/`issued?` em cada classe RTC espelham a discriminação clássica (`is_a?` E predicado), consistente com os subtipos `Nfe::Resources::ServiceInvoicePending`/`Nfe::Resources::ServiceInvoiceIssued` de `add-invoice-resources`.

## Capabilities

### New Capabilities
- `rtc-invoice-emission`: recursos dedicados `service_invoices_rtc` (NFS-e, grupo raiz `ibsCbs`) e `product_invoices_rtc` (NF-e/NFC-e, grupos item-level `IBSCBS` com `state`/`municipal`/`cbs` e `IS`/Imposto Seletivo), ambos com contrato discriminado 202, validação de IDs, polling manual via `FlowStatus`, downloads binários e — para NFS-e — o download do XML de evento de cancelamento (Ambiente Nacional).

### Modified Capabilities
- (nenhuma) — esta change é puramente aditiva. NÃO modifica a capability `invoice-resources` (de `add-invoice-resources`): os recursos clássicos `service_invoices` e `product_invoices` permanecem inalterados.

## Impact

- **Código afetado**:
  - NFS-e RTC: novo `lib/nfe/resources/service_invoices_rtc.rb`; novos `lib/nfe/resources/service_invoice_rtc_pending.rb` e `service_invoice_rtc_issued.rb`; DTOs gerados em `lib/nfe/generated/service_invoice_rtc_v1/`; assinaturas em `sig/nfe/resources/service_invoices_rtc.rbs` e `sig/nfe/generated/service_invoice_rtc_v1/`.
  - NF-e/NFC-e RTC: novo `lib/nfe/resources/product_invoices_rtc.rb`; novos `lib/nfe/resources/product_invoice_rtc_pending.rb` e `product_invoice_rtc_issued.rb`; DTOs gerados em `lib/nfe/generated/product_invoice_rtc_v1/`; assinaturas em `sig/nfe/resources/product_invoices_rtc.rbs` e `sig/nfe/generated/product_invoice_rtc_v1/`.
  - Novos accessors lazy `service_invoices_rtc` e `product_invoices_rtc` em `lib/nfe/client.rb` (passa a expor 19 accessors); assinatura do `Client` atualizada.
- **Spec impact**: adiciona a capability `rtc-invoice-emission`. Sem deltas MODIFIED.
- **Dependências**: `add-client-core` (contrato 202 `Pending`/`Issued`, `FlowStatus`, `IdValidator`, `download`/`hydrate_list`/`handle_async_response` do `Nfe::Resources::AbstractResource`, `ListResponse`/`ListPage`, host map / roteamento multi-base-URL), `add-invoice-resources` (superfícies clássicas `service_invoices`/`product_invoices` e padrões dos subtipos `ServiceInvoicePending`/`ServiceInvoiceIssued`), `add-openapi-pipeline` (geração de DTOs `Data.define` + `.rbs` para as duas specs RTC).
- **Risks**:
  - O leiaute RTC está **sujeito a Notas Técnicas** e homologação — tratamos as duas specs como snapshots fixados (`NT_2025.002_v1.30_RTC` para NFS-e; `NT_2025.002_v1.30_RTC_NF-e_IBS_CBS_IS` para produto) e re-sincronizamos a cada NT.
  - Quatro caminhos de emissão (clássico vs RTC, para serviço e para produto) podem confundir — mitigado por nomes distintos, doc clara e opt-in explícito.
  - `download_cancellation_xml` (NFS-e) só existe em Ambiente Nacional — documentamos o 404 esperado para municipal/ABRASF e mapeamos para `Nfe::NotFoundError`.
  - A spec RTC de produto documenta o `create` como `201` (a superfície clássica trata como `202`-enfileirado) — o recurso trata ambos via contrato discriminado; emissão é sempre assíncrona (conclusão por webhook/polling). O Ambiente Nacional NÃO se aplica ao produto (NF-e/NFC-e vai direto à SEFAZ).
  - O volume de schemas do produto (140) é grande; o gerador pode não tipar todos os subgrupos aninhados de `IBSCBS`/`IS` — mantemos `Hash` como fallback no caminho de request.
