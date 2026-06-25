# Tasks — add-invoice-resources

> Planejamento greenfield. Todos os itens estão `[ ]` (não implementados). Depende de `add-client-core` (transporte `Net::HTTP`, `Nfe::Configuration` com host map, erros tipados, contrato `Pending`/`Issued`, acessores lazy). A emissão RTC fica em `add-rtc-invoice-emission`.

## 1. Suporte consumido de add-client-core (validators, ListResponse, FlowStatus)

> NÃO recriar estas abstrações — `add-client-core` já as define. Esta seção apenas confirma o contrato consumido e cobre as integrações.

- [ ] 1.1 Consumir `Nfe::IdValidator` (de `add-client-core`) — métodos de módulo `company_id`, `invoice_id`, `state_tax_id`, `event_key`, e `access_key` (normaliza removendo não-dígitos, valida `/\A\d{44}\z/`, retorna a String normalizada). Cada método levanta `Nfe::InvalidRequestError` com mensagem em pt-BR identificando o argumento inválido. NÃO criar `Nfe::Util::IdValidator`.
- [ ] 1.2 Consumir `Nfe::ListPage = Data.define(:page_index, :page_count, :starting_after, :ending_before, :total)` (de `add-client-core`) com defaults `nil`. NÃO recriar.
- [ ] 1.3 Consumir `Nfe::ListResponse = Data.define(:data, :page)` (de `add-client-core`); `data` é `Array`, `page` é `Nfe::ListPage`; já inclui `Enumerable` (delega `each` para `data`). NÃO recriar.
- [ ] 1.4 Consumir `Nfe::FlowStatus.terminal?(status)` (de `add-client-core`) — `true` para `Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`; `false` para os demais. NÃO recriar `Nfe::Util::FlowStatus`.
- [ ] 1.5 Confirmar que as assinaturas RBS de `Nfe::IdValidator`, `Nfe::ListPage`, `Nfe::ListResponse`, `Nfe::FlowStatus` (de `add-client-core`) cobrem o uso desta change; nenhum RBS novo para estes tipos aqui.
- [ ] 1.6 Tests de integração: exercitar `Nfe::IdValidator` (vazio → erro; access_key com separadores → 44 dígitos; comprimento errado → erro), `Nfe::FlowStatus.terminal?` (4 terminais → true; não-terminais → false) e `Nfe::ListResponse` (Enumerable, shapes page e cursor) nos specs dos recursos que os consomem.

## 2. Helpers de download/unwrapping no recurso-base (AbstractResource de add-client-core)

> `Nfe::Resources::AbstractResource` (de `add-client-core`) já provê `download`, `hydrate`, `hydrate_list`, `handle_async_response` e `get/post/put/delete`. Esta seção só confirma o consumo e cobre a lacuna específica de invoice (unwrapping de envelope).

- [ ] 2.1 Consumir `Nfe::Resources::AbstractResource#download(path)` (de `add-client-core`) para os downloads de bytes — GET com `Accept` apropriado, retorna `response.body` como `String` em `Encoding::ASCII_8BIT` (binary-safe), sem decodificar como JSON.
- [ ] 2.2 Adicionar `Nfe::Resources::AbstractResource#unwrap(payload, *keys)` (protegido) — desempacota envelopes do tipo `{ "serviceInvoice" => {...} }` retornando o primeiro `key` presente, ou `payload` se nenhum existir. (Extensão aditiva à base, se ainda não existir.)
- [ ] 2.3 Consumir `Nfe::Resources::AbstractResource#hydrate_list(klass, payload, wrapper_key:)` (de `add-client-core`) — desempacota `{ <wrapper_key> => [...] }`, hidrata cada item, detecta o shape de paginação (page-style vs cursor-style) e devolve `Nfe::ListResponse` com `Nfe::ListPage` preenchido na metade correta.
- [ ] 2.4 Garantir que cada recurso declara sua `api_family` (`:main` para service; `:cte` para product/consumer/transportation/inbound), resolvida via `Nfe::Configuration#base_url_for(family)` (de `add-client-core`).
- [ ] 2.5 RBS: atualizar `sig/nfe/resources/abstract_resource.rbs` apenas se `unwrap` for adicionado; demais assinaturas já vêm de `add-client-core`.
- [ ] 2.6 Tests: cobrir `unwrap` (desempacota e cai no fallback) nos specs dos recursos; `download`/`hydrate_list` já são cobertos por `add-client-core`.

## 3. Response value objects (Pending + Issued)

- [ ] 3.1 `lib/nfe/resources/service_invoice_pending.rb` — `Nfe::Resources::ServiceInvoicePending = Data.define(:invoice_id, :location)`; método `pending?` → `true`, `issued?` → `false`.
- [ ] 3.2 `lib/nfe/resources/service_invoice_issued.rb` — `Nfe::Resources::ServiceInvoiceIssued = Data.define(:resource)` onde `resource` é o modelo de invoice hidratado; `pending?` → `false`, `issued?` → `true`.
- [ ] 3.3 `lib/nfe/resources/product_invoice_pending.rb` + `product_invoice_issued.rb`.
- [ ] 3.4 `lib/nfe/resources/consumer_invoice_pending.rb` + `consumer_invoice_issued.rb`.
- [ ] 3.5 Helper de extração de `invoice_id` a partir do header `Location` (regex `%r{serviceinvoices/([a-z0-9-]+)}i` para service; `%r{(?:product|consumer)invoices/([a-z0-9-]+)}i` para os demais). Levantar `Nfe::InvoiceProcessingError` se 202 vier sem `Location` ou se o ID não for extraível.
- [ ] 3.6 RBS para cada par Pending/Issued em `sig/nfe/resources/`.
- [ ] 3.7 Tests: `spec/nfe/resources/invoice_response_spec.rb` — `pending?`/`issued?`, extração de `invoice_id` do `Location`, erro quando `Location` ausente.

## 4. service_invoices (NFS-e — recurso canônico, host main → api.nfe.io; `/v1` via api_version, URL efetiva api.nfe.io/v1)

- [ ] 4.1 `lib/nfe/resources/service_invoices.rb` — classe `Nfe::Resources::ServiceInvoices < Nfe::Resources::AbstractResource`, `api_family :main`.
- [ ] 4.2 `create(company_id:, data:, idempotency_key: nil, request_options: nil)` — `POST /companies/{company_id}/serviceinvoices`. Se 202 → `ServiceInvoicePending` (extrai `invoice_id` do `Location`); se 201 → `ServiceInvoiceIssued` (hidrata o body). Levanta `InvoiceProcessingError` se 202 sem `Location`. `idempotency_key:` vira header `Idempotency-Key`; `request_options:` (`Nfe::RequestOptions`) é encaminhado ao request (vide design D13).
- [ ] 4.3 `list(company_id:, **options)` — `GET /companies/{company_id}/serviceinvoices` com query `page_index`, `page_count`, `issued_begin`, `issued_end`, `created_begin`, `created_end`, `has_totals` (page-style). Devolve `ListResponse` com `ListPage` page-style (wrapper `serviceInvoices`).
- [ ] 4.4 `retrieve(company_id:, invoice_id:)` — `GET .../{invoice_id}`. Levanta `Nfe::NotFoundError` se corpo vazio/404.
- [ ] 4.5 `cancel(company_id:, invoice_id:)` — `DELETE .../{invoice_id}`; retorna o modelo de invoice atualizado (síncrono).
- [ ] 4.6 `send_email(company_id:, invoice_id:)` — `PUT .../{invoice_id}/sendemail`; retorna `{ sent:, message: }` (sem argumento de lista de e-mails — paridade Node).
- [ ] 4.7 `download_pdf(company_id:, invoice_id: nil)` — `GET .../{invoice_id}/pdf` ou, se `invoice_id` nil, `GET .../serviceinvoices/pdf` (download em lote → ZIP). `Accept: application/pdf`. Retorna `String` binária.
- [ ] 4.8 `download_xml(company_id:, invoice_id: nil)` — `GET .../{invoice_id}/xml` ou em lote `.../serviceinvoices/xml`. `Accept: application/xml`. Retorna `String` binária.
- [ ] 4.9 `get_status(company_id:, invoice_id:)` — DERIVADO de `retrieve` (sem chamada HTTP extra, paridade Node). Retorna `Data.define(:status, :invoice, :complete?, :failed?)` usando `FlowStatus.terminal?` e checagem de `IssueFailed`/`CancelFailed`.
- [ ] 4.10 Validar `company_id`/`invoice_id` via `IdValidator` no início de cada método.
- [ ] 4.11 RBS: `sig/nfe/resources/service_invoices.rbs`.
- [ ] 4.12 Tests `spec/nfe/resources/service_invoices_spec.rb` (WebMock): 202→Pending, 201→Issued, 202-sem-Location→erro, list page-style, retrieve, retrieve 404→NotFoundError, cancel, send_email, download_pdf bytes começam com `%PDF`, download_xml começa com `<`, download em lote (invoice_id nil), get_status derivado, IDs inválidos→InvalidRequestError sem HTTP, `idempotency_key:` enviado como header `Idempotency-Key`, `request_options:` (api_key por chamada) sobrescrevendo o default sem mutar o `Client`.

## 5. product_invoices (NF-e — host cte / api.nfse.io)

- [ ] 5.1 `lib/nfe/resources/product_invoices.rb` — `Nfe::Resources::ProductInvoices < Nfe::Resources::AbstractResource`, `api_family :cte`.
- [ ] 5.2 `create(company_id:, data:, idempotency_key: nil, request_options: nil)` — `POST /v2/companies/{company_id}/productinvoices`; resposta discriminada `ProductInvoicePending|ProductInvoiceIssued` (async 202 enfileirado, conclusão via webhook). `idempotency_key:`/`request_options:` conforme design D13.
- [ ] 5.3 `create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)` — `POST /v2/companies/{company_id}/statetaxes/{state_tax_id}/productinvoices`; valida `state_tax_id`. `idempotency_key:`/`request_options:` conforme design D13.
- [ ] 5.4 `list(company_id:, environment:, **options)` — `GET /v2/companies/{company_id}/productinvoices` (cursor: `starting_after`, `ending_before`, `limit`, `q`). `environment` (`"Production"`/`"Test"`) é OBRIGATÓRIO → `InvalidRequestError` se ausente. Devolve `ListResponse` cursor-style.
- [ ] 5.5 `retrieve(company_id:, invoice_id:)` — `GET .../{invoice_id}`.
- [ ] 5.6 `cancel(company_id:, invoice_id:, reason: nil)` — `DELETE .../{invoice_id}?reason={reason}`; retorna recurso de cancelamento (async 204 enfileirado).
- [ ] 5.7 `list_items(company_id:, invoice_id:, limit: nil, starting_after: nil)` — `GET .../{invoice_id}/items` (cursor).
- [ ] 5.8 `list_events(company_id:, invoice_id:, limit: nil, starting_after: nil)` — `GET .../{invoice_id}/events` (cursor).
- [ ] 5.9 `download_pdf(company_id:, invoice_id:, force: nil)` — `GET .../{invoice_id}/pdf?force={force}`; retorna `NfeFileResource` (URI, NÃO bytes). Documentar a divergência.
- [ ] 5.10 `download_xml(company_id:, invoice_id:)` — `GET .../{invoice_id}/xml`; retorna `NfeFileResource` (URI).
- [ ] 5.11 `download_rejection_xml(company_id:, invoice_id:)` — `GET .../{invoice_id}/xml-rejection`; retorna `NfeFileResource` (URI). (Path Node `/xml-rejection`.)
- [ ] 5.12 `download_epec_xml(company_id:, invoice_id:)` — `GET .../{invoice_id}/xml-epec`; retorna `NfeFileResource` (URI). (XML de contingência EPEC.)
- [ ] 5.13 `send_correction_letter(company_id:, invoice_id:, reason:)` — `PUT .../{invoice_id}/correctionletter`; valida `15 <= reason.length <= 1000` (sem acentos) client-side antes do HTTP; body `{ reason: }`. Retorna recurso de cancelamento (CC-e async).
- [ ] 5.14 `download_correction_letter_pdf(company_id:, invoice_id:)` — `GET .../{invoice_id}/correctionletter/pdf`; `NfeFileResource`.
- [ ] 5.15 `download_correction_letter_xml(company_id:, invoice_id:)` — `GET .../{invoice_id}/correctionletter/xml`; `NfeFileResource`.
- [ ] 5.16 `disable(company_id:, invoice_id:, reason: nil)` — `POST .../{invoice_id}/disablement?reason={reason}` (inutilização por invoice, async).
- [ ] 5.17 `disable_range(company_id:, data:)` — `POST /v2/companies/{company_id}/productinvoices/disablement` com `{ environment, serie, state, begin_number, last_number, reason? }` (faixa; número único = mesmo begin/last).
- [ ] 5.18 Validar IDs via `IdValidator`; validar tamanho da carta de correção.
- [ ] 5.19 RBS: `sig/nfe/resources/product_invoices.rbs`.
- [ ] 5.20 Tests `spec/nfe/resources/product_invoices_spec.rb`: routing para `api.nfse.io`, create discriminado, create_with_state_tax, list cursor + environment obrigatório, retrieve, cancel com reason em query, list_items/list_events, download_* retornam URI (NfeFileResource), correction letter (15-1000 chars + erro fora do range), disable, disable_range.

## 6. consumer_invoices (NFC-e — paridade-plus, host cte / api.nfse.io)

> Recurso ALÉM da paridade Node (Node não expõe emissão de NFC-e). Fundamentado em `nf-consumidor-v2.yaml`. Documentar paridade-plus + 3 ausências por lei fiscal (vide design D7).

- [ ] 6.1 `lib/nfe/resources/consumer_invoices.rb` — `Nfe::Resources::ConsumerInvoices < Nfe::Resources::AbstractResource`, `api_family :cte`. Comentário de cabeçalho documentando "paridade-plus" e as 3 ausências.
- [ ] 6.2 `create(company_id:, data:, idempotency_key: nil, request_options: nil)` — `POST /v2/companies/{company_id}/consumerinvoices`; discriminado `ConsumerInvoicePending|ConsumerInvoiceIssued` (202/201). `idempotency_key:`/`request_options:` conforme design D13.
- [ ] 6.3 `create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)` — `POST /v2/companies/{company_id}/statetaxes/{state_tax_id}/consumerinvoices`. `idempotency_key:`/`request_options:` conforme design D13.
- [ ] 6.4 `list(company_id:, **options)` — `GET .../consumerinvoices` (cursor; wrapper `consumerInvoices`).
- [ ] 6.5 `retrieve(company_id:, invoice_id:)` — `GET .../{invoice_id}`.
- [ ] 6.6 `cancel(company_id:, invoice_id:)` — `DELETE .../{invoice_id}` (síncrono); retorna o modelo atualizado.
- [ ] 6.7 `list_items(company_id:, invoice_id:)` — `GET .../{invoice_id}/items`.
- [ ] 6.8 `list_events(company_id:, invoice_id:)` — `GET .../{invoice_id}/events`.
- [ ] 6.9 `download_pdf(company_id:, invoice_id:)` — `GET .../{invoice_id}/pdf`; retorna `String` binária (DANFE NFC-e, ao contrário do product). `Accept: application/pdf`.
- [ ] 6.10 `download_xml(company_id:, invoice_id:)` — `GET .../{invoice_id}/xml`; retorna `String` binária.
- [ ] 6.11 `download_rejection_xml(company_id:, invoice_id:)` — `GET .../{invoice_id}/xml/rejection`; retorna `String` binária.
- [ ] 6.12 `disable_range(company_id:, data:)` — `POST .../consumerinvoices/disablement` (inutilização SOMENTE coletiva).
- [ ] 6.13 NÃO definir `send_correction_letter`, `download_epec_xml`, nem `disable` por invoice (verificar via teste que esses métodos não respondem).
- [ ] 6.14 Validar IDs via `IdValidator`.
- [ ] 6.15 RBS: `sig/nfe/resources/consumer_invoices.rbs`.
- [ ] 6.16 Tests `spec/nfe/resources/consumer_invoices_spec.rb`: routing `api.nfse.io`, create discriminado 202/201, create_with_state_tax, list cursor, retrieve, cancel síncrono, downloads (bytes), disable_range, e asserções de que os 3 métodos ausentes levantam `NoMethodError`.

## 7. transportation_invoices (CT-e — inbound, host cte / api.nfse.io)

- [ ] 7.1 `lib/nfe/resources/transportation_invoices.rb` — `Nfe::Resources::TransportationInvoices < Nfe::Resources::AbstractResource`, `api_family :cte`.
- [ ] 7.2 `enable(company_id:, start_from_nsu: nil, start_from_date: nil)` — `POST /v2/companies/{company_id}/inbound/transportationinvoices`; habilita busca automática de CT-e via Distribuição DFe; retorna settings.
- [ ] 7.3 `disable(company_id:)` — `DELETE /v2/companies/{company_id}/inbound/transportationinvoices`; retorna settings.
- [ ] 7.4 `get_settings(company_id:)` — `GET /v2/companies/{company_id}/inbound/transportationinvoices`; retorna settings.
- [ ] 7.5 `retrieve(company_id:, access_key:)` — `GET /v2/companies/{company_id}/inbound/{access_key}`; valida `access_key` (44 dígitos); retorna metadata.
- [ ] 7.6 `download_xml(company_id:, access_key:)` — `GET .../inbound/{access_key}/xml`; retorna `String` (XML).
- [ ] 7.7 `get_event(company_id:, access_key:, event_key:)` — `GET .../inbound/{access_key}/events/{event_key}`; retorna metadata.
- [ ] 7.8 `download_event_xml(company_id:, access_key:, event_key:)` — `GET .../inbound/{access_key}/events/{event_key}/xml`; retorna `String` (XML).
- [ ] 7.9 Validar `company_id`/`access_key`/`event_key` via `IdValidator`.
- [ ] 7.10 RBS: `sig/nfe/resources/transportation_invoices.rbs`.
- [ ] 7.11 Tests `spec/nfe/resources/transportation_invoices_spec.rb`: routing `api.nfse.io`, enable/disable/get_settings, retrieve com normalização de access_key (espaços/pontos → 44 dígitos), access_key inválida→InvalidRequestError, download_xml, get_event, download_event_xml.

## 8. inbound_product_invoices (NF-e recebida de fornecedores, host cte / api.nfse.io)

- [ ] 8.1 `lib/nfe/resources/inbound_product_invoices.rb` — `Nfe::Resources::InboundProductInvoices < Nfe::Resources::AbstractResource`, `api_family :cte`.
- [ ] 8.2 `enable_auto_fetch(company_id:, start_from_nsu: nil, start_from_date: nil, environment_sefaz: nil, automatic_manifesting: nil, webhook_version: nil)` — `POST /v2/companies/{company_id}/inbound/productinvoices`; retorna settings.
- [ ] 8.3 `disable_auto_fetch(company_id:)` — `DELETE .../inbound/productinvoices`; retorna settings.
- [ ] 8.4 `get_settings(company_id:)` — `GET .../inbound/productinvoices`; retorna settings.
- [ ] 8.5 `get_details(company_id:, access_key:)` — `GET .../inbound/{access_key}`; metadata genérica NF-e/CT-e (webhook v1).
- [ ] 8.6 `get_product_invoice_details(company_id:, access_key:)` — `GET .../inbound/productinvoice/{access_key}`; metadata v2 recomendada (+`productInvoices[]`).
- [ ] 8.7 `get_event_details(company_id:, access_key:, event_key:)` — `GET .../inbound/{access_key}/events/{event_key}`.
- [ ] 8.8 `get_product_invoice_event_details(company_id:, access_key:, event_key:)` — `GET .../inbound/productinvoice/{access_key}/events/{event_key}`.
- [ ] 8.9 `get_xml(company_id:, access_key:)` — `GET .../inbound/{access_key}/xml`; retorna `String` (XML).
- [ ] 8.10 `get_event_xml(company_id:, access_key:, event_key:)` — `GET .../inbound/{access_key}/events/{event_key}/xml`; retorna `String`.
- [ ] 8.11 `get_pdf(company_id:, access_key:)` — `GET .../inbound/{access_key}/pdf`; retorna `String` binária (bytes do PDF).
- [ ] 8.12 `get_json(company_id:, access_key:)` — `GET .../inbound/productinvoice/{access_key}/json`; retorna metadata estruturada (Hash hidratado).
- [ ] 8.13 `manifest(company_id:, access_key:, tp_event: 210210)` — `POST .../inbound/{access_key}/manifest?tpEvent={tp_event}`. Aceitar código numérico (`210210` Ciência (default), `210220` Confirmação, `210240` Operação não Realizada). Expor constantes simbólicas no módulo (`MANIFEST_AWARENESS = 210210`, etc.). Retorna `String`.
- [ ] 8.14 `reprocess_webhook(company_id:, access_key_or_nsu:)` — `POST .../inbound/productinvoice/{access_key_or_nsu}/processwebhook`; aceita chave de 44 dígitos OU número NSU.
- [ ] 8.15 Validar IDs via `IdValidator` (access_key 44 dígitos; `reprocess_webhook` tolera NSU numérico).
- [ ] 8.16 RBS: `sig/nfe/resources/inbound_product_invoices.rbs`.
- [ ] 8.17 Tests `spec/nfe/resources/inbound_product_invoices_spec.rb`: routing `api.nfse.io`, enable/disable/get_settings, get_details vs get_product_invoice_details (v1 vs v2 path), eventos, get_xml/get_event_xml (string), get_pdf (bytes), get_json (Hash), manifest com tpEvent default e explícito, reprocess_webhook com access_key e com NSU.

## 9. Modelos gerados (DTOs de invoice)

- [ ] 9.1 Confirmar quais modelos de invoice o gerador OpenAPI cobre (de `nf-servico-v1.yaml`, `nf-produto-v2.yaml`, `nf-consumidor-v2.yaml`, `consulta-cte-v2.yaml`, `consulta-nfe-distribuicao-v1.yaml`). NOTA: `nf-servico-v1.yaml` tem 0 schemas de componente — o modelo de service-invoice é derivado das operações.
- [ ] 9.2 Onde o gerador não cobrir o shape de resposta, criar value objects `Data.define` hand-written sob `lib/nfe/models/` (NÃO em `lib/nfe/generated/`, para não conflitar com o sync do gerador) com os campos que o SDK realmente acessa (`id`, `flow_status`, `flow_message`, `status`, `environment`, `rps_number`, `rps_serial_number`, etc.). Documentar quais foram hand-written.
- [ ] 9.3 `Nfe::Models::NfeFileResource = Data.define(:uri, ...)` — modelo de retorno dos downloads de `product_invoices` (URI, não bytes).
- [ ] 9.4 RBS para os modelos hand-written em `sig/nfe/models/`.

## 10. Integração no Client

- [ ] 10.1 Confirmar que os acessores lazy `service_invoices`, `product_invoices`, `consumer_invoices`, `transportation_invoices`, `inbound_product_invoices` em `Nfe::Client` (de `add-client-core`) agora instanciam as classes reais (não stubs) passando o transporte/config correto por família.
- [ ] 10.2 Confirmar roteamento de host: service → `:main` (host `api.nfe.io`; `/v1` via api_version, URL efetiva `api.nfe.io/v1`); os outros 4 → `:cte` (api.nfse.io).
- [ ] 10.3 Tests `spec/nfe/client_spec.rb` — cada acessor devolve a classe concreta esperada e é memoizado (mesma instância em chamadas repetidas).

## 11. Validação e qualidade

- [ ] 11.1 `bundle exec rspec` — cobertura SimpleCov >= 80%.
- [ ] 11.2 `bundle exec steep check` — 0 erros de tipo nos novos arquivos (`lib/nfe/resources/`, `lib/nfe/models/`).
- [ ] 11.3 `bundle exec rubocop` — sem offenses; todo `.rb` começa com `# frozen_string_literal: true`.
- [ ] 11.4 `openspec validate add-invoice-resources` — passa.
- [ ] 11.5 CI matrix Ruby 3.2 / 3.3 / 3.4 verde.

## 12. Documentação

- [ ] 12.1 YARD/comentários em cada método público (paridade com o JSDoc Node + notas pt-BR onde fizer sentido).
- [ ] 12.2 README — tabela com os 5 recursos + exemplo 1-liner de emissão de service invoice e de leitura do retorno discriminado (`case result; in ServiceInvoicePending => p ...`).
- [ ] 12.3 Documentar no README: downloads de `product_invoices` retornam URI (NfeFileResource), os demais retornam bytes; `consumer_invoices` é paridade-plus; `create_and_wait`/`create_batch` diferidos (mostrar loop manual com `FlowStatus.terminal?`); cross-reference para `add-rtc-invoice-emission`.

## 13. Smoke test manual (opt-in, fora do CI)

- [ ] 13.1 NFS-e ponta-a-ponta: emissão + polling manual até estado terminal (precisa chave sandbox + company cadastrada).
- [ ] 13.2 `download_pdf` retornando bytes que começam com `%PDF`; `download_xml` começando com `<`.
- [ ] 13.3 Listagem com paginação real (page-style em service, cursor em product/consumer).
- [ ] 13.4 CT-e: configurar auto-fetch + consultar por access_key.
- [ ] 13.5 NFC-e: emissão paridade-plus em sandbox antes do GA.
- [ ] 13.6 Registrar resultados em `.notes/invoice-smoke-results.md`.
