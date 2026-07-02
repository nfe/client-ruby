# Tasks — add-lookup-resources

> Plano greenfield para o SDK Ruby v1 (gem `nfe-io` 1.0.0). Todos os itens estão UNCHECKED.
> **Depende de add-client-core**: `Nfe::Configuration` (host map), `Nfe::Resources::AbstractResource` (`get`/`post`/`put`/`delete`/`download`/`hydrate`), `Nfe::IdValidator` base (`company_id`, `state_tax_id`, `access_key`), `Nfe::ListResponse`/`Nfe::ListPage`, accessores lazy no `Nfe::Client`, classes de erro (`Nfe::InvalidRequestError`, `Nfe::NotFoundError`, etc.). Transitivamente depende de **add-ruby-foundation**.
> Convenções: todo `.rb` começa com `# frozen_string_literal: true`; value objects são `Data.define`; keyword args; snake_case; zero dependências de runtime (só stdlib). Arquivos sob `lib/nfe/generated/` NUNCA são editados à mão.

## 1. Suporte: extensão do IdValidator + DateNormalizer

- [x] 1.1 Estender `lib/nfe/id_validator.rb` (módulo base de add-client-core) com `cep(value) -> String` — normaliza removendo não-dígitos, valida exatamente 8 dígitos; `raise Nfe::InvalidRequestError` com mensagem pt-BR se vazio ou comprimento != 8.
- [x] 1.2 Adicionar `state(value) -> String` — `strip` + `upcase`; valida contra o conjunto das 29 UFs (`AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO` + `EX` + `NA`); retorna a UF maiúscula; `raise` para qualquer outro código.
- [x] 1.3 Adicionar `cnpj(value) -> String` — remove não-dígitos, valida 14 dígitos; retorna normalizado; `raise` se vazio/comprimento errado.
- [x] 1.4 Adicionar `cpf(value) -> String` — remove não-dígitos, valida 11 dígitos; retorna normalizado; `raise` se vazio/comprimento errado.
- [x] 1.5 Confirmar reuso de `access_key` (44 dígitos), `company_id`, `state_tax_id` de add-client-core — não redefinir; só consumir.
- [x] 1.6 Criar `lib/nfe/date_normalizer.rb` — módulo `Nfe::DateNormalizer` com `to_iso_date(input) -> String`: aceita `String` (regex `/\A\d{4}-\d{2}-\d{2}\z/` + roundtrip `Date.iso8601` que rejeita mês/dia fora de faixa) e `Date`/`Time`/`DateTime` (via `strftime("%Y-%m-%d")`, descartando hora); `raise Nfe::InvalidRequestError` para formato inválido, data fora de faixa ou tipo inesperado. `require "date"`/`"time"` da stdlib.
- [x] 1.7 Assinaturas RBS: `sig/nfe/id_validator.rbs` (cep/state/cnpj/cpf) e `sig/nfe/date_normalizer.rbs` (`to_iso_date: (String | Date | Time | DateTime) -> String`).
- [x] 1.8 Specs: `spec/nfe/date_normalizer_spec.rb` (string passthrough, conversão de `Date`/`Time`, formato inválido `15/01/1990`, fora de faixa `2026-13-45`, tipo inesperado) + estender `spec/nfe/id_validator_spec.rb` (cep com/sem hífen, comprimento errado, state lower→upper, `EX`/`NA` aceitos, `ZZ` rejeitado, cnpj/cpf com pontuação normalizados).

## 2. AddressesResource

- [x] 2.1 Criar `lib/nfe/resources/addresses.rb` — `class Nfe::Resources::Addresses < Nfe::Resources::AbstractResource`; `api_family` → `:addresses`; `api_version` → `""` (o `/v2` está na base URL `address.api.nfe.io/v2`).
- [x] 2.2 `lookup_by_postal_code(postal_code) -> AddressLookupResponse` — `cep = Nfe::IdValidator.cep(postal_code)`; `GET /addresses/#{cep}`.
- [x] 2.3 `search(filter: nil) -> AddressLookupResponse` — `GET /addresses` com query `{ "$filter" => filter }` quando `filter` presente; repassa opaco (sem parser OData).
- [x] 2.4 `lookup_by_term(term) -> AddressLookupResponse` — rejeita `term` vazio/whitespace (`raise Nfe::InvalidRequestError`); `GET /addresses/#{CGI.escape(term.strip)}`.
- [x] 2.5 Value object `AddressLookupResponse` — checar `lib/nfe/generated/` (spec `consulta-endereco`); se ausente, criar `Data.define` hand-written em `lib/nfe/resources/dto/addresses/address_lookup_response.rb` (`addresses:` lista de `Address` com `street`, `street_suffix`, `postal_code`, `city`, `state`, etc.).
- [x] 2.6 RBS `sig/nfe/resources/addresses.rbs`.
- [x] 2.7 Spec `spec/nfe/resources/addresses_spec.rb` — assertiona host de saída `https://address.api.nfe.io/v2`; CEP com hífen → path `/addresses/01310100`; CEP comprimento inválido → `Nfe::InvalidRequestError` sem HTTP; `search` repassa `$filter`; term vazio rejeitado.

## 3. LegalEntityLookupResource

- [x] 3.1 Criar `lib/nfe/resources/legal_entity_lookup.rb` — `< Nfe::Resources::AbstractResource`; `api_family` → `:legal_entity` (host `https://legalentity.api.nfe.io`); paths usam `/v2/legalentities/...`.
- [x] 3.2 `get_basic_info(federal_tax_number, update_address: nil, update_city_code: nil) -> LegalEntityBasicInfoResponse` — `cnpj = Nfe::IdValidator.cnpj(...)`; monta query só com os opts não-nil; `GET /v2/legalentities/basicInfo/#{cnpj}`.
- [x] 3.3 `get_state_tax_info(state, federal_tax_number) -> LegalEntityStateTaxResponse` — `state = Nfe::IdValidator.state(...)`, `cnpj = Nfe::IdValidator.cnpj(...)`; `GET /v2/legalentities/stateTaxInfo/#{state}/#{cnpj}`.
- [x] 3.4 `get_state_tax_for_invoice(state, federal_tax_number) -> LegalEntityStateTaxForInvoiceResponse` — `GET /v2/legalentities/stateTaxForInvoice/#{state}/#{cnpj}`.
- [x] 3.5 `get_suggested_state_tax_for_invoice(state, federal_tax_number) -> LegalEntityStateTaxForInvoiceResponse` — `GET /v2/legalentities/stateTaxSuggestedForInvoice/#{state}/#{cnpj}`.
- [x] 3.6 Value objects — checar `lib/nfe/generated/` (spec `consulta-cnpj`); hand-written em `lib/nfe/resources/dto/legal_entity_lookup/` onde o gen não cobrir (`LegalEntityBasicInfoResponse { legal_entity: ... }`, `LegalEntityStateTaxResponse`, `LegalEntityStateTaxForInvoiceResponse`).
- [x] 3.7 RBS `sig/nfe/resources/legal_entity_lookup.rbs`.
- [x] 3.8 Spec `spec/nfe/resources/legal_entity_lookup_spec.rb` — host de saída `https://legalentity.api.nfe.io`; CNPJ com pontuação `12.345.678/0001-90` → `12345678000190`; state lower `sp` → `SP` no path; state inválido `XX` → `Nfe::InvalidRequestError` sem HTTP; opts `update_address`/`update_city_code` viram query params.

## 4. NaturalPersonLookupResource

- [x] 4.1 Criar `lib/nfe/resources/natural_person_lookup.rb` — `< Nfe::Resources::AbstractResource`; `api_family` → `:natural_person` (host `https://naturalperson.api.nfe.io`); paths `/v1/naturalperson/...`.
- [x] 4.2 `get_status(federal_tax_number, birth_date) -> NaturalPersonStatusResponse` — `cpf = Nfe::IdValidator.cpf(...)`, `date = Nfe::DateNormalizer.to_iso_date(birth_date)` (aceita `String`|`Date`|`Time`|`DateTime`); `GET /v1/naturalperson/status/#{cpf}/#{date}`.
- [x] 4.3 Value object `NaturalPersonStatusResponse` — hand-written `Data.define` em `lib/nfe/resources/dto/natural_person_lookup/natural_person_status_response.rb` (`name`, `federal_tax_number`, `birth_on`, `status`, `created_on`, todos opcionais) — spec de CPF é esparso.
- [x] 4.4 RBS `sig/nfe/resources/natural_person_lookup.rbs`.
- [x] 4.5 Spec `spec/nfe/resources/natural_person_lookup_spec.rb` — host `https://naturalperson.api.nfe.io`; CPF formatado `123.456.789-01` → digits-only; `birth_date` como `String` ISO e como `Date` produzem o mesmo path; formato inválido `15/01/1990` → `Nfe::InvalidRequestError`; data fora de faixa `2026-13-45` → `Nfe::InvalidRequestError`.

## 5. ProductInvoiceQueryResource

- [x] 5.1 Criar `lib/nfe/resources/product_invoice_query.rb` — `< Nfe::Resources::AbstractResource`; `api_family` → `:nfe_query` (host `https://nfe.api.nfe.io`); paths internos com prefixo `/v2/productinvoices`.
- [x] 5.2 `retrieve(access_key) -> ProductInvoiceDetails` — `key = Nfe::IdValidator.access_key(...)`; `GET /v2/productinvoices/#{key}`.
- [x] 5.3 `download_pdf(access_key) -> String` — `download("/v2/productinvoices/#{key}.pdf", accept: "application/pdf")`; retorna `String` binária (`%PDF...`).
- [x] 5.4 `download_xml(access_key) -> String` — `download("/v2/productinvoices/#{key}.xml", accept: "application/xml")`; retorna `String` binária (`<...`).
- [x] 5.5 `list_events(access_key) -> ProductInvoiceEventsResponse` — `GET /v2/productinvoices/events/#{key}`.
- [x] 5.6 Value objects — checar `lib/nfe/generated/` (spec `consulta-nf`); hand-written `ProductInvoiceDetails` e `ProductInvoiceEventsResponse { events:, created_on: }` em `lib/nfe/resources/dto/product_invoice_query/` se o gen não cobrir.
- [x] 5.7 RBS `sig/nfe/resources/product_invoice_query.rbs`.
- [x] 5.8 Spec `spec/nfe/resources/product_invoice_query_spec.rb` — host `https://nfe.api.nfe.io`; access key com espaços/pontos → 44 dígitos; `123` → `Nfe::InvalidRequestError`; download manda `Accept` correto e retorna bytes; path de download usa sufixo `.pdf`/`.xml`.

## 6. ConsumerInvoiceQueryResource

> Consulta de NFC-e por chave de acesso (CFe-SAT). **Distinto** de `consumer_invoices` (emissão NFC-e) de **add-invoice-resources** — host e versão diferentes. Cross-reference no comentário/RBS.

- [x] 6.1 Criar `lib/nfe/resources/consumer_invoice_query.rb` — `< Nfe::Resources::AbstractResource`; `api_family` → `:nfe_query` (mesmo host `https://nfe.api.nfe.io` que product query, mas paths `v1` + `/coupon/`).
- [x] 6.2 `retrieve(access_key) -> TaxCoupon` — `key = Nfe::IdValidator.access_key(...)`; `GET /v1/consumerinvoices/coupon/#{key}`.
- [x] 6.3 `download_xml(access_key) -> String` — `download("/v1/consumerinvoices/coupon/#{key}.xml", accept: "application/xml")`; retorna `String` binária.
- [x] 6.4 Value object `TaxCoupon` hand-written em `lib/nfe/resources/dto/consumer_invoice_query/tax_coupon.rb` — campos canônicos do Node (`current_status`, `number`, `sat_serie`, `software_version`, `software_federal_tax_number`, `access_key`, `cashier`, `issued_on`, `created_on`, `xml_version`, `issuer`, `buyer`, `totals`, `delivery`, `additional_information`, `items`, `payment`), todos opcionais. Sub-objetos (`CouponIssuer`, `CouponBuyer`, `CouponTotal`, `CouponDelivery`, `CouponAdditionalInformation`, `CouponItem`, `CouponPayment`) como `Data.define` aninhados quando referenciados.
- [x] 6.5 RBS `sig/nfe/resources/consumer_invoice_query.rbs`.
- [x] 6.6 Spec `spec/nfe/resources/consumer_invoice_query_spec.rb` — host `https://nfe.api.nfe.io`; path `v1` + `/coupon/`; access key normalizada; `download_xml` usa `.xml` no path e retorna bytes.

## 7. TaxCalculationResource

- [x] 7.1 Criar `lib/nfe/resources/tax_calculation.rb` — `< Nfe::Resources::AbstractResource`; `api_family` → `:cte` (host `https://api.nfse.io`); `api_version` → `""` (paths começam em `/tax-rules`).
- [x] 7.2 `calculate(tenant_id, request) -> CalculateResponse` — validação local: `tenant_id` não vazio, `request` com `operation_type`/`operationType` presente e `items` array não vazio; `raise Nfe::InvalidRequestError` senão; `POST /tax-rules/#{CGI.escape(tenant_id.strip)}/engine/calculate` com `request` como body JSON.
- [x] 7.3 `request` aceita `Hash`; comentário/RBS recomendam `Nfe::Generated::CalculoImpostosV1::CalculateRequest#to_h` para type-safety.
- [x] 7.4 Value object `CalculateResponse` — checar `lib/nfe/generated/` (spec `calculo-impostos`); hand-written em `lib/nfe/resources/dto/tax_calculation/calculate_response.rb` se ausente (`items:` com breakdown ICMS/PIS/COFINS/IPI/II + `cfop`).
- [x] 7.5 RBS `sig/nfe/resources/tax_calculation.rbs`.
- [x] 7.6 Spec `spec/nfe/resources/tax_calculation_spec.rb` — host `https://api.nfse.io`; path `/tax-rules/{tenant}/engine/calculate` com tenant URL-encodado; `tenant_id` vazio → `Nfe::InvalidRequestError` sem HTTP; `items: []` → `Nfe::InvalidRequestError`; body enviado como JSON.

## 8. TaxCodesResource

- [x] 8.1 Criar `lib/nfe/resources/tax_codes.rb` — `< Nfe::Resources::AbstractResource`; `api_family` → `:cte` (host `https://api.nfse.io`); `api_version` → `""` (paths `/tax-codes/...`).
- [x] 8.2 `list_operation_codes(page_index: nil, page_count: nil) -> TaxCodePaginatedResponse` — `GET /tax-codes/operation-code` com query 1-based (`pageIndex`/`pageCount`) só quando presentes.
- [x] 8.3 `list_acquisition_purposes(page_index: nil, page_count: nil)` — `GET /tax-codes/acquisition-purpose`.
- [x] 8.4 `list_issuer_tax_profiles(page_index: nil, page_count: nil)` — `GET /tax-codes/issuer-tax-profile`.
- [x] 8.5 `list_recipient_tax_profiles(page_index: nil, page_count: nil)` — `GET /tax-codes/recipient-tax-profile`.
- [x] 8.6 Value object `TaxCodePaginatedResponse` hand-written em `lib/nfe/resources/dto/tax_codes/tax_code_paginated_response.rb` (`current_page`, `total_pages`, `total_count`, `items` de `TaxCode { code, description }`). Page-style 1-based — documentar que difere do cursor das outras listas.
- [x] 8.7 RBS `sig/nfe/resources/tax_codes.rbs`.
- [x] 8.8 Spec `spec/nfe/resources/tax_codes_spec.rb` — host `https://api.nfse.io`; default omite `pageIndex`/`pageCount`; explícito `page_index: 2, page_count: 20` aparece na query (1-based preservado); os 4 paths corretos.

## 9. StateTaxesResource (CRUD)

- [x] 9.1 Criar `lib/nfe/resources/state_taxes.rb` — `< Nfe::Resources::AbstractResource`; `api_family` → `:cte` (host `https://api.nfse.io`); base path `/v2/companies/#{company_id}/statetaxes`.
- [x] 9.2 `list(company_id, starting_after: nil, ending_before: nil, limit: nil) -> Nfe::ListResponse` — `Nfe::IdValidator.company_id(...)`; cursor-style; `GET` base path com query dos cursores presentes; `ListPage` carrega cursores (não `page_index`).
- [x] 9.3 `create(company_id, data) -> NfeStateTax` — envelopa body como `{ stateTax: data }`; `POST` base path.
- [x] 9.4 `retrieve(company_id, state_tax_id) -> NfeStateTax` — `Nfe::IdValidator.state_tax_id(...)`; `GET base/#{state_tax_id}`.
- [x] 9.5 `update(company_id, state_tax_id, data) -> NfeStateTax` — envelopa `{ stateTax: data }`; `PUT base/#{state_tax_id}`.
- [x] 9.6 `delete(company_id, state_tax_id) -> nil` — `DELETE base/#{state_tax_id}`; retorna `nil` (200/204).
- [x] 9.7 Value object `NfeStateTax` — checar `lib/nfe/generated/` (spec `contribuintes-v2`/`nf-produto-v2`); hand-written em `lib/nfe/resources/dto/state_taxes/nfe_state_tax.rb` se ausente (`id`, `tax_number`, `serie`, `number`, `code`, `environment_type`, `type`, `status`).
- [x] 9.8 RBS `sig/nfe/resources/state_taxes.rbs`.
- [x] 9.9 Spec `spec/nfe/resources/state_taxes_spec.rb` — host `https://api.nfse.io`; `create` envia `{"stateTax": {...}}`; `update` idem; `list` cursor-style (`ListPage` com cursores); `delete` retorna `nil`; validação de `company_id`/`state_tax_id` vazios → `Nfe::InvalidRequestError` sem HTTP.

## 10. Integração com o Client (accessores lazy)

- [x] 10.1 Confirmar que os 8 accessores snake_case estão registrados no `Nfe::Client` (definidos em add-client-core): `addresses`, `legal_entity_lookup`, `natural_person_lookup`, `product_invoice_query`, `consumer_invoice_query`, `tax_calculation`, `tax_codes`, `state_taxes`. Esta change só provê as classes que esses accessores instanciam lazy.
- [x] 10.2 `require` dos 8 arquivos de recurso + `date_normalizer` no autoload de `lib/nfe.rb` (ou no manifesto que add-client-core usa).
- [x] 10.3 Spec de fumaça em `spec/nfe/client_spec.rb` (estende o de add-client-core): cada um dos 8 accessores devolve a classe correta e roteia para o host esperado quando um método é chamado com transporte mockado.

## 11. Type-check, lint e cobertura

- [x] 11.1 `steep check` — 0 erros para os arquivos novos (`lib/nfe/resources/*.rb`, `date_normalizer.rb`, extensão de `id_validator.rb` + RBS correspondentes).
- [x] 11.2 `rubocop` — sem ofensas; todo `.rb` com `# frozen_string_literal: true`.
- [x] 11.3 `rspec` — todos os specs desta change verdes.
- [x] 11.4 SimpleCov — cobertura >= 80% mantida com os novos arquivos.
- [x] 11.5 `openspec validate add-lookup-resources` — passa.

## 12. Documentação

- [x] 12.1 README — adicionar os 8 recursos à tabela de acessores com 1-liner cada (pt-BR), destacando a seção "Roteamento multi-host" (hosts dedicados).
- [x] 12.2 Comentários/YARD em cada método público com exemplo idiomático Ruby (paridade com o JSDoc do Node, em pt-BR onde fizer sentido).
- [x] 12.3 Nota explícita de cross-reference: `consumer_invoice_query` (consulta por chave) vs `consumer_invoices` (emissão, de add-invoice-resources).

## 13. Smoke test manual (opt-in, fora do CI)

- [ ] 13.1 CEP lookup `01310-100` retorna Av. Paulista — DEFERRED (precisa chave de dados).
- [ ] 13.2 CNPJ basicInfo lookup — DEFERRED.
- [ ] 13.3 CPF status (cpf + birth_date) — DEFERRED.
- [ ] 13.4 Tax calculation operação simples — DEFERRED.
- [ ] 13.5 Tax codes paginação 1-based — DEFERRED.
- [ ] 13.6 Product invoice query + download_pdf (bytes `%PDF`) — DEFERRED.
- [ ] 13.7 Consumer invoice query (coupon) + download_xml — DEFERRED.
- [ ] 13.8 State taxes CRUD end-to-end — DEFERRED.
- [ ] 13.9 Registrar resultados em `.notes/lookup-smoke-results.md` — DEFERRED.
