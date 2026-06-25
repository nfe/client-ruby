# Tasks — add-rtc-invoice-emission

> Greenfield planning. Todos os itens UNCHECKED. Depende de `add-client-core` (contrato 202 `Pending`/`Issued`, `FlowStatus`, `IdValidator`, `download`/`hydrate_list`/`handle_async_response` do `Nfe::Resources::AbstractResource`, `ListResponse`/`ListPage`, host map / roteamento multi-base-URL), de `add-invoice-resources` (superfícies clássicas `service_invoices`/`product_invoices` e padrões dos subtipos `ServiceInvoicePending`/`ServiceInvoiceIssued`) e de `add-openapi-pipeline` (geração de DTOs `Data.define` + assinaturas `.rbs`).
>
> A change cobre DOIS recursos RTC: **NFS-e** (`service_invoices_rtc`, §§1–6) e **NF-e/NFC-e** (`product_invoices_rtc`, §§7–11). Ordem sugerida: §1 (pipeline NFS-e) → §2 (responses NFS-e) → §3 (resource NFS-e) → §4 (client wiring) → §5 (testes NFS-e) → §7 (pipeline produto) → §8 (responses produto) → §9 (resource produto) → §10 (testes produto) → §6/§11 (docs/validação).

## 1. Pipeline: sincronizar e gerar DTOs RTC (depende de add-openapi-pipeline)

- [ ] 1.1 Adicionar `service-invoice-rtc-v1.yaml` ao manifesto de specs do gerador, sincronizando a partir de `nfeio-docs` (fonte da verdade; o snapshot fixado é `NT_2025.002_v1.30_RTC`, `version: v3`). Registrar a origem e a data do snapshot em comentário do manifesto.
- [ ] 1.2 Rodar o gerador e confirmar que ele emite, sob `lib/nfe/generated/service_invoice_rtc_v1/`, value objects `Data.define` imutáveis para os 18 schemas nomeados: `NFSeRequest`, `ibsCbs`, `addressDefinition`, `partyDefinition`, `serviceAmountDefinitions`, `activityEvent`, `approximateTax`, `ReferenceSubstitution`, `lease`, `construction`, `realEstate`, `foreignTrade`, `deduction`, `deductionDocument`, `benefit`, `suspension`, `approximateTotals`, `thirdPartyReimbursementDocument`.
- [ ] 1.3 Confirmar que o subgrupo aninhado `ibsCbs` gera (ou expõe via tipos aninhados) os campos do grupo IBS/CBS: `operation_indicator` (cIndOp, `^[0-9]{6}$`), `class_code` (cClassTrib, max 6), `situation_code` (CST, opcional/derivável), `purpose` (enum `regular`, default), `destination_indicator` (`SameAsBuyer`/`DifferentFromBuyer`), `basis`, `reimbursed_resupplied_amount`, `is_donation`, `personal_use`, e os subgrupos `ibs` (com `state`/`municipal`, cada um com `rate`/`effective_rate`/`deferment`/`amount`), `cbs` (`rate`/`effective_rate`/`deferment`/`amount`), `regular_taxation`, `presumed_credits`, `government_purchase`, `credit_transfer`, `third_party_reimbursements`.
- [ ] 1.4 Confirmar nomes de campo em `snake_case` no Ruby gerado (ex.: `operationIndicator` → `operation_indicator`, `nbsCode` → `nbs_code`, `servicesAmount` → `services_amount`), com a chave JSON original preservada na serialização.
- [ ] 1.5 Confirmar geração das assinaturas `sig/nfe/generated/service_invoice_rtc_v1/*.rbs` e que `bin/steep check` passa sobre os tipos gerados.
- [ ] 1.6 Cada arquivo gerado inicia com `# frozen_string_literal: true` e o banner "DO NOT hand-edit — generated" do pipeline. NÃO editar manualmente nenhum arquivo sob `lib/nfe/generated/`.

## 2. Classes de resposta (Pending + Issued concretas)

- [ ] 2.1 Criar `lib/nfe/resources/service_invoice_rtc_pending.rb` definindo `Nfe::Resources::ServiceInvoiceRtcPending` — implementa o protocolo `Nfe::Pending` de `add-client-core`; expõe `invoice_id` (extraído do header `Location` via regex `%r{serviceinvoices/([a-z0-9-]+)}i`), `location` e os predicados `pending?` (→ `true`) / `issued?` (→ `false`). Imutável (`Data.define`). `# frozen_string_literal: true`.
- [ ] 2.2 Criar `lib/nfe/resources/service_invoice_rtc_issued.rb` definindo `Nfe::Resources::ServiceInvoiceRtcIssued` — implementa o protocolo `Nfe::Issued` de `add-client-core`; expõe `resource` retornando o DTO `Nfe::Generated::ServiceInvoiceRtcV1` de service-invoice hidratado do corpo 201 e os predicados `issued?` (→ `true`) / `pending?` (→ `false`). Imutável.
- [ ] 2.3 Reusar o mesmo extrator de `invoice_id` do header `Location` que os subtipos clássicos de `add-invoice-resources` usam (não duplicar a regex); levantar `Nfe::InvoiceProcessingError` quando o 202 não trouxer header `Location`.
- [ ] 2.4 Assinaturas `sig/nfe/resources/service_invoice_rtc_pending.rbs` e `sig/nfe/resources/service_invoice_rtc_issued.rbs`.

## 3. Recurso `ServiceInvoicesRtc`

- [ ] 3.1 Criar `lib/nfe/resources/service_invoices_rtc.rb` com `# frozen_string_literal: true`. Herda do `Nfe::Resources::AbstractResource` (de `add-client-core`). `api_family` retorna `:main` → `base_url_for(:main)` resolve o host `https://api.nfe.io` via `Configuration` e o `/v1` vem do `api_version` do recurso (URL efetiva `https://api.nfe.io/v1/...`; sem hard-code de URL; reusa o mesmo host client do `service_invoices` clássico).
- [ ] 3.2 `create(company_id:, data:, idempotency_key: nil, request_options: nil)` — `POST /companies/{company_id}/serviceinvoices`. Aceita `data` como `Nfe::Generated::ServiceInvoiceRtcV1::NFSeRequest` OU `Hash`. Trata a resposta discriminada: 202 + `Location` → `Nfe::Resources::ServiceInvoiceRtcPending`; 201 + corpo → `Nfe::Resources::ServiceInvoiceRtcIssued`. `idempotency_key:` → header `Idempotency-Key` (POST NÃO auto-retried); `request_options:` (`Nfe::RequestOptions` de `add-client-core`) repassado ao request/transport (override de `api_key`/`base_url`/`timeout` por chamada). Documentar no comentário que o leiaute RTC é selecionado pela presença do grupo `ibsCbs` no payload (sem header/param) e que é o **mesmo endpoint** do `service_invoices` clássico.
- [ ] 3.3 `retrieve(company_id:, invoice_id:)` — `GET /companies/{company_id}/serviceinvoices/{invoice_id}`; hidrata o DTO de service-invoice RTC; levanta `Nfe::NotFoundError` quando não houver dados (404).
- [ ] 3.4 `cancel(company_id:, invoice_id:)` — `DELETE /companies/{company_id}/serviceinvoices/{invoice_id}`; retorna o DTO de invoice atualizado (síncrono).
- [ ] 3.5 `download_cancellation_xml(company_id:, invoice_id:)` — `GET /companies/{company_id}/serviceinvoices/{invoice_id}/cancellation-xml` com `Accept: application/xml`. Usa o helper `download` do `Nfe::Resources::AbstractResource`; retorna `String` binária (`force_encoding('ASCII-8BIT')`). Documentar: apenas Ambiente Nacional (ADN), só após status `Cancelled`; 404 (municipal/ABRASF ou ainda não cancelada) → `Nfe::NotFoundError`.
- [ ] 3.6 Validar IDs no início de cada método via `Nfe::IdValidator.company_id` e `Nfe::IdValidator.invoice_id` (de `add-client-core`), levantando `Nfe::InvalidRequestError` em pt-BR antes de qualquer chamada HTTP (fail-fast).
- [ ] 3.7 Expor (documentar) o helper de polling manual: o caller usa `retrieve` em loop até `Nfe::FlowStatus.terminal?(invoice.flow_status)`. NÃO implementar `create_and_wait` nem `create_batch` (vide design D5).
- [ ] 3.8 Comentário de cabeçalho do recurso documentando a superfície RTC vs clássica e o status "leiaute sujeito a Notas Técnicas (snapshot NT_2025.002_v1.30_RTC)".

## 4. Wiring no Client

- [ ] 4.1 Adicionar accessor lazy `service_invoices_rtc` em `lib/nfe/client.rb` — instancia `Nfe::Resources::ServiceInvoicesRtc` sob demanda, passando o host client `main` (reusado, não um novo). Snake_case, consistente com os demais accessors.
- [ ] 4.2 Adicionar accessor lazy `product_invoices_rtc` em `lib/nfe/client.rb` — instancia `Nfe::Resources::ProductInvoicesRtc` sob demanda, passando o host client `cte`/`api.nfse.io` (reusado, mesmo do `product_invoices` clássico, não um novo). Snake_case.
- [ ] 4.3 Atualizar a contagem de accessors do Client (passa de 17 para 19 com os dois recursos RTC) onde houver asserção/documentação dessa contagem, deixando claro que `service_invoices_rtc` e `product_invoices_rtc` são **paridade-plus / adendo RTC** (não constam dos 17 recursos canônicos do PHP/Node).
- [ ] 4.4 Assinaturas `sig/nfe/resources/service_invoices_rtc.rbs` e `sig/nfe/resources/product_invoices_rtc.rbs` e atualização da assinatura do `Client` para incluir os dois novos accessors.

## 5. Testes (RSpec, cobertura >= 80%)

- [ ] 5.1 `spec/nfe/resources/service_invoices_rtc_spec.rb` — `create` 202 → `Nfe::Resources::ServiceInvoiceRtcPending` com `invoice_id` extraído do `Location` e `location` correto.
- [ ] 5.2 `create` 201 → `Nfe::Resources::ServiceInvoiceRtcIssued` com `resource` hidratado a partir do corpo.
- [ ] 5.3 `create` 202 sem header `Location` → levanta `Nfe::InvoiceProcessingError`.
- [ ] 5.4 `create` com payload mínimo do exemplo `MinimumExample` da spec (`borrower`, `cityServiceCode`, `federalServiceCode`, `description`, `servicesAmount`, `nbsCode`, `ibsCbs{operationIndicator, classCode}`) — assertar que o corpo enviado contém o grupo `ibsCbs` com `operation_indicator` `^[0-9]{6}$` e `class_code`.
- [ ] 5.5 `create` com `IntermediateExample` (subgrupos `ibs.state`/`ibs.municipal`/`cbs`) — round-trip do DTO `Data.define`.
- [ ] 5.6 `retrieve` happy path → DTO tipado; 404 → `Nfe::NotFoundError`.
- [ ] 5.7 `cancel` → DTO atualizado (síncrono).
- [ ] 5.8 `download_cancellation_xml` → `String` binária começando com `<` (após BOM opcional); encoding `ASCII-8BIT`.
- [ ] 5.9 `download_cancellation_xml` 404 (provedor municipal/ABRASF ou nota não cancelada) → `Nfe::NotFoundError`.
- [ ] 5.10 Validação fail-fast: `company_id`/`invoice_id` vazio ou em branco → `Nfe::InvalidRequestError` SEM chamada HTTP (verificar via stub que o transport não foi invocado).
- [ ] 5.10b `create(..., idempotency_key: "k")` → request carrega header `Idempotency-Key: k`; sem o kwarg, nenhum header `Idempotency-Key` é enviado. `create(..., request_options: Nfe::RequestOptions.new(api_key: "tenant-key", ...))` → autentica com `tenant-key` só naquela chamada, sem mutar o Client compartilhado.
- [ ] 5.11 Roteamento: a requisição de qualquer método sai para o host `https://api.nfe.io` (família `main`; `/v1` via `api_version`, URL efetiva `https://api.nfe.io/v1/...`), idêntico ao `service_invoices` clássico.
- [ ] 5.12 `spec/nfe/client_spec.rb` — `client.service_invoices_rtc` retorna uma instância funcional (memoizada na segunda leitura); contagem de accessors atualizada.
- [ ] 5.13 Regressão: confirmar que `client.service_invoices` (clássico, de `add-invoice-resources`) permanece inalterado por esta change.

## 6. Documentação, tipos e validação

- [ ] 6.1 README/exemplo: emissão de NFS-e RTC com grupo `ibsCbs` + loop de polling manual via `FlowStatus.terminal?`; nota de que RTC é opt-in via `service_invoices_rtc` e o clássico continua disponível.
- [ ] 6.2 Documentar o snapshot fixado (`NT_2025.002_v1.30_RTC`) e o processo de re-sync a cada Nota Técnica.
- [ ] 6.3 `bin/steep check` (Steep) limpo sobre o novo recurso, responses e DTOs.
- [ ] 6.4 RuboCop limpo nos novos arquivos (`# frozen_string_literal: true` em todos).
- [ ] 6.5 SimpleCov >= 80% no novo recurso.
- [ ] 6.6 `openspec validate add-rtc-invoice-emission --strict` passa.

## 7. Pipeline: sincronizar e gerar DTOs RTC de produto (depende de add-openapi-pipeline)

- [ ] 7.1 Adicionar `product-invoice-rtc-v1.yaml` ao manifesto de specs do gerador, sincronizando a partir de `nfeio-docs` (`docs/static/api/`; snapshot fixado `NT_2025.002_v1.30_RTC_NF-e_IBS_CBS_IS`, `version: v3`, OpenAPI 3.0.1, host `https://api.nfse.io`). Registrar origem e data do snapshot em comentário do manifesto.
- [ ] 7.2 Rodar o gerador e confirmar que ele emite, sob `lib/nfe/generated/product_invoice_rtc_v1/`, value objects `Data.define` imutáveis para os 140 schemas nomeados, incluindo a raiz `ProductInvoiceRequest` (`required: items, payment`), `InvoiceResource`, `InvoiceWithoutEventsResource`, `ProductInvoicesResource`, `InvoiceItemResource`, `InvoiceItemTaxResource`, `RequestCancellationResource`, `DisablementResource`, `FileResource`, `ErrorResource`/`ErrorsResource`, `InvoiceEventsResource`/`ActivityResource`, `InvoiceItemsResource` e `TaxpayerCommentsResource`.
- [ ] 7.3 Confirmar que `InvoiceItemTaxResource` (em `items[].tax`) gera (ou expõe via tipos aninhados) os DOIS novos grupos RTC de nível de item, lado a lado com os grupos legados (`icms`/`ipi`/`ii`/`pis`/`cofins`/`icmsDestination`): (1) `IS` → `ISTaxResource` (Imposto Seletivo: `situation_code`, `classification_code`, `basis`, `rate`, `unit_rate`, `unit`, `quantity`, `amount`); (2) `IBSCBS` → `IBSCBSTaxResource`.
- [ ] 7.4 Confirmar que `IBSCBSTaxResource` gera os campos `situation_code` (CST, derivável de `class_code`), `class_code` (cClassTrib, max 6), `calculation_mode` (enum `Manual`|`OfficialService`, default `Manual`), `donation_indicator`, `basis`, `ibs_total_amount`, e os subgrupos `state` → `IBSStateTaxResource`, `municipal` → `IBSMunicipalTaxResource`, `cbs` → `CBSTaxResource`, mais os mecanismos `regular_taxation`, `government_purchase`, `monophase`, `credit_transfer`, `operational_presumed_credit`, `credit_reversal`, `zfm_presumed_credit`.
- [ ] 7.5 Confirmar que `IBSStateTaxResource` e `IBSMunicipalTaxResource` têm a mesma forma (`rate`, `deferment` → `DefermentTaxResource`, `returned_amount` → `ReturnedTaxResource`, `reduction` → `ReductionTaxResource`, `amount`), e que `CBSTaxResource` é federal (mesmos `rate`/`deferment`/`returned_amount`/`reduction`/`amount`, SEM split estadual/municipal).
- [ ] 7.6 Confirmar geração do campo item-level `competence_adjustment` → `CompetenceAdjustmentResource` (gAjusteCompet) e dos totais (`IBSCBSTotalsResource`, `IBSTotalsResource`, `IBSStateTotalsResource`, `IBSMunicipalTotalsResource`, `CBSTotalsResource`, `ISTotalsResource`, `Monophase*Totals`, `TotalsWithholdings`).
- [ ] 7.7 Confirmar geração dos enums `PrintType` (`None`|`NFeNormalPortrait`|`NFeNormalLandscape`|`NFeSimplified`|`DANFE_NFC_E`|`DANFE_NFC_E_MSG_ELETRONICA`), `OperationType`, `ConsumerType`, `ConsumerPresenceType`, `PurposeType`, `InvoiceStatus` (`None`|`Created`|`Processing`|`Issued`|`IssuedContingency`|`Cancelled`|`Disabled`|`IssueDenied`|`Error`).
- [ ] 7.8 Confirmar nomes de campo em `snake_case` no Ruby gerado (chave JSON original preservada na serialização) e geração das assinaturas `sig/nfe/generated/product_invoice_rtc_v1/*.rbs`; `bin/steep check` limpo.
- [ ] 7.9 Cada arquivo gerado inicia com `# frozen_string_literal: true` e o banner "DO NOT hand-edit — generated". NÃO editar manualmente nada sob `lib/nfe/generated/`.

## 8. Classes de resposta de produto (Pending + Issued concretas)

- [ ] 8.1 Criar `lib/nfe/resources/product_invoice_rtc_pending.rb` definindo `Nfe::Resources::ProductInvoiceRtcPending` — implementa o protocolo `Nfe::Pending`; expõe `invoice_id` (extraído do header `Location` via regex `%r{productinvoices/([a-z0-9-]+)}i`), `location` e os predicados `pending?` (→ `true`) / `issued?` (→ `false`). Imutável (`Data.define`). `# frozen_string_literal: true`.
- [ ] 8.2 Criar `lib/nfe/resources/product_invoice_rtc_issued.rb` definindo `Nfe::Resources::ProductInvoiceRtcIssued` — implementa o protocolo `Nfe::Issued`; expõe `resource` retornando o DTO `Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource` hidratado do corpo 201 e os predicados `issued?` (→ `true`) / `pending?` (→ `false`). Imutável.
- [ ] 8.3 Reusar o mesmo padrão de extração de `invoice_id` do header `Location` dos subtipos clássicos; levantar `Nfe::InvoiceProcessingError` quando o 202 não trouxer header `Location`.
- [ ] 8.4 Assinaturas `sig/nfe/resources/product_invoice_rtc_pending.rbs` e `sig/nfe/resources/product_invoice_rtc_issued.rbs`.

## 9. Recurso `ProductInvoicesRtc`

- [ ] 9.1 Criar `lib/nfe/resources/product_invoices_rtc.rb` com `# frozen_string_literal: true`. Herda do `Nfe::Resources::AbstractResource`. `api_family` retorna `:cte` (alias `:product_invoices`) → `base_url_for(:cte)` resolve `https://api.nfse.io`; `api_version` retorna `"v2"` (URL efetiva `https://api.nfse.io/v2/...`). Sem hard-code de URL; reusa o mesmo host client do `product_invoices` clássico.
- [ ] 9.2 `create(company_id:, data:, idempotency_key: nil, request_options: nil)` — `POST /companies/{company_id}/productinvoices`. Aceita `data` como `Nfe::Generated::ProductInvoiceRtcV1::ProductInvoiceRequest` OU `Hash`. Trata a resposta discriminada: 202 + `Location` → `Nfe::Resources::ProductInvoiceRtcPending`; 201 + corpo → `Nfe::Resources::ProductInvoiceRtcIssued`. `idempotency_key:` → header `Idempotency-Key` (POST NÃO auto-retried); `request_options:` (`Nfe::RequestOptions`) repassado ao request/transport (override por chamada). Documentar no comentário: leiaute RTC selecionado pela presença do grupo item-level `IBSCBS` (sem header/param); NF-e (mod 55) vs NFC-e (mod 65) por forma do payload; emissão sempre assíncrona (spec documenta 201, clássico trata como 202).
- [ ] 9.3 `create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)` — `POST /companies/{company_id}/statetaxes/{state_tax_id}/productinvoices`; mesmo corpo e mesmo tratamento discriminado de resposta; mesmos `idempotency_key:`/`request_options:` do `create`. Validar `state_tax_id` via `Nfe::IdValidator.state_tax_id`.
- [ ] 9.4 `retrieve(company_id:, invoice_id:)` — `GET /companies/{company_id}/productinvoices/{invoice_id}`; hidrata `InvoiceResource`; 404 → `Nfe::NotFoundError`.
- [ ] 9.5 `list(company_id:, environment:, starting_after: nil, ending_before: nil, limit: nil, q: nil)` — `GET /companies/{company_id}/productinvoices`; `environment` obrigatório; paginação por cursor via `hydrate_list` → `Nfe::ListResponse`/`Nfe::ListPage` (wrapper `ProductInvoicesResource`, `product_invoices[]` + `has_more`).
- [ ] 9.6 `cancel(company_id:, invoice_id:, reason: nil)` — `DELETE /companies/{company_id}/productinvoices/{invoice_id}?reason=`; assíncrono (204-enfileirado); retorna `RequestCancellationResource`.
- [ ] 9.7 `list_items(company_id:, invoice_id:)` — `GET .../items` (`InvoiceItemsResource`); `list_events(company_id:, invoice_id:)` — `GET .../events` (`InvoiceEventsResource` de `ActivityResource`).
- [ ] 9.8 Downloads (retornam `Nfe::Models::NfeFileResource` com `uri`, igual à superfície clássica `product_invoices` e ao schema `FileResource{uri}` de `nf-produto-v2.yaml` — NÃO bytes `ASCII-8BIT` crus): `download_pdf(company_id:, invoice_id:, force: false)` → `.../pdf?force=`; `download_xml` → `.../xml`; `download_rejection_xml` → `.../xml-rejection`; `download_epec_xml` → `.../xml-epec`.
- [ ] 9.9 CC-e: `send_correction_letter(company_id:, invoice_id:, reason:)` — `PUT .../correctionletter` (corpo `{reason}`; `reason` 15–1000 chars, sem acentos/especiais; assíncrono); `download_correction_letter_pdf` → `.../correctionletter/pdf`; `download_correction_letter_xml` → `.../correctionletter/xml` (downloads retornam `Nfe::Models::NfeFileResource` com `uri`, igual à superfície clássica `product_invoices`).
- [ ] 9.10 Inutilização: `disable(company_id:, invoice_id:, reason:)` — `POST .../productinvoices/{invoice_id}/disablement?reason=` (assíncrono); `disable_range(company_id:, data:)` — `POST .../productinvoices/disablement` (corpo `DisablementResource`-shaped: `environment`, `serie`, `state`, `begin_number`, `last_number`, `reason?`), retorna `DisablementResource`.
- [ ] 9.11 Validar IDs no início de cada método via `Nfe::IdValidator.company_id`/`.invoice_id`/`.state_tax_id`, levantando `Nfe::InvalidRequestError` em pt-BR antes de qualquer HTTP (fail-fast).
- [ ] 9.12 Documentar polling manual: caller usa `retrieve` em loop até `Nfe::FlowStatus.terminal?(invoice.flow_status)`. NÃO implementar `create_and_wait`/`create_batch` (vide design D5). Comentário de cabeçalho documentando superfície RTC vs clássica, host `api.nfse.io`, e snapshot `NT_2025.002_v1.30_RTC_NF-e_IBS_CBS_IS`.

## 10. Testes de produto (RSpec, cobertura >= 80%)

- [ ] 10.1 `spec/nfe/resources/product_invoices_rtc_spec.rb` — `create` 202 → `Nfe::Resources::ProductInvoiceRtcPending` com `invoice_id` extraído do `Location` (`%r{productinvoices/([a-z0-9-]+)}i`) e `location` correto.
- [ ] 10.2 `create` 201 → `Nfe::Resources::ProductInvoiceRtcIssued` com `resource` (`InvoiceResource`) hidratado.
- [ ] 10.3 `create` 202 sem header `Location` → `Nfe::InvoiceProcessingError`.
- [ ] 10.4 `create` com payload portando o grupo item-level `IBSCBS` — assertar que o corpo enviado contém `items[].tax.IBSCBS` com os subgrupos `state`/`municipal`/`cbs` e que IBS é dividido em estadual+municipal enquanto CBS é federal (sem split).
- [ ] 10.5 `create` com grupo item-level `IS` (Imposto Seletivo) presente — round-trip do DTO `Data.define` (`situation_code`/`classification_code`/`rate`/`amount`).
- [ ] 10.6 NFC-e vs NF-e: dois payloads — um NF-e (mod 55, `printType` NFe*, `buyer` presente) e um NFC-e (mod 65, `printType` `DANFE_NFC_E`, `consumerType`/`presenceType`, sem `buyer`/`expectedDeliveryOn`) — ambos passam pelo MESMO `create`/endpoint; assertar que nenhum header/param discriminador é enviado.
- [ ] 10.7 `create_with_state_tax` → POST contra `.../statetaxes/{state_tax_id}/productinvoices`; `state_tax_id` inválido → `Nfe::InvalidRequestError` sem HTTP.
- [ ] 10.8 `retrieve` happy path → `InvoiceResource`; 404 → `Nfe::NotFoundError`.
- [ ] 10.9 `list` → `Nfe::ListResponse` com `product_invoices` e paginação por cursor; `environment` ausente → `ArgumentError`.
- [ ] 10.10 `cancel` → `RequestCancellationResource`; `reason` repassado como query param.
- [ ] 10.11 `list_items` / `list_events` → DTOs tipados.
- [ ] 10.12 Downloads (`download_pdf`/`download_xml`/`download_rejection_xml`/`download_epec_xml`/`download_correction_letter_pdf`/`download_correction_letter_xml`) → `Nfe::Models::NfeFileResource` com `uri` (igual à superfície clássica `product_invoices` e ao schema `FileResource{uri}` de `nf-produto-v2.yaml`); NÃO bytes `ASCII-8BIT` crus.
- [ ] 10.13 `send_correction_letter` → assíncrono; `disable`/`disable_range` → DTOs corretos.
- [ ] 10.14 Validação fail-fast: `company_id`/`invoice_id` vazio → `Nfe::InvalidRequestError` SEM chamada HTTP (verificar via stub que o transport não foi invocado).
- [ ] 10.14b `create`/`create_with_state_tax(..., idempotency_key: "k")` → header `Idempotency-Key: k`; sem o kwarg, nenhum header enviado. `request_options:` (`Nfe::RequestOptions`) → override de `api_key` por chamada sem mutar o Client.
- [ ] 10.15 Roteamento: a requisição de qualquer método sai para o host `https://api.nfse.io` (família `cte`; `/v2` via `api_version`, URL efetiva `https://api.nfse.io/v2/...`), idêntico ao `product_invoices` clássico.
- [ ] 10.16 `spec/nfe/client_spec.rb` — `client.product_invoices_rtc` retorna instância funcional (memoizada); contagem de accessors atualizada (19).
- [ ] 10.17 Regressão: confirmar que `client.product_invoices` (clássico) permanece inalterado por esta change.

## 11. Documentação e validação (produto)

- [ ] 11.1 README/exemplo: emissão de NF-e/NFC-e RTC com grupos item-level `IBSCBS` (`state`/`municipal`/`cbs`) e `IS`; nota distinguindo NF-e (mod 55) de NFC-e (mod 65) por forma do payload; loop de polling manual via `FlowStatus.terminal?`; nota de que RTC é opt-in via `product_invoices_rtc` e o clássico continua disponível.
- [ ] 11.2 Documentar o snapshot fixado (`NT_2025.002_v1.30_RTC_NF-e_IBS_CBS_IS`) e o processo de re-sync por Nota Técnica.
- [ ] 11.3 `bin/steep check` limpo sobre `ProductInvoicesRtc`, suas responses e DTOs; RuboCop limpo (`# frozen_string_literal: true` em todos); SimpleCov >= 80% no novo recurso.

## 12. Fora de escopo (registrado explicitamente)

- [ ] 12.1 `create_and_wait` / `create_batch` — diferidos (vide design D5), consistente com `add-invoice-resources`, para ambos os recursos RTC.
- [ ] 12.2 Validação runtime/local dos campos RTC (ex.: tabelas de `operationIndicator`/`classCode`/`situationCode`, valores de IS) — a API valida server-side; o SDK só faz fail-fast de ID/access-key.
- [ ] 12.3 Novos EVENTOS de pós-autorização do RTC documentados no `fluxograma-ciclo-vida-nfe.md` (Solicitação de Apropriação de Crédito Presumido, Imobilização de Item, Destinação para Consumo Pessoal, Informação de Pagamento Integral, Perecimento/Perda/Roubo no Transporte, Atualização da Data de Previsão de Entrega) — ainda NÃO são endpoints na spec RTC; fora de escopo até virarem paths.
- [ ] 12.4 Motor de cálculo de IBS/CBS/IS (`calculo-impostos-v1`) — outro escopo; aqui o caller informa os valores no payload.
