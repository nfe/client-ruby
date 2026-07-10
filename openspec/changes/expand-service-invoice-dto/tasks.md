# Tasks: expand-service-invoice-dto (client-ruby)

## 1. Spec OpenAPI & código gerado (absorve a atualização local do yaml)

- [x] 1.1 Incluir a atualização de `openapi/nf-servico-v1.yaml` (já no working tree: `ErrorsResource` em `components.schemas` + `content` nas respostas 4xx/5xx) no escopo da change
- [x] 1.2 `rake generate` e commitar junto a saída (`lib/nfe/generated/nf_servico_v1/` com o modelo de erros, `sig/nfe/generated/nf_servico_v1/`, `lib/nfe/generated.rb`, `generated_marker.rb`) — fluxo documentado "commit specs and generated files together"; `rake generate:check` verde
- [x] 1.3 Atualizar `openapi/README.md`: `nf-servico-v1.yaml` sai da lista de exemplos pulados (`cpf-api.yaml` permanece); notar que o namespace gerado cobre só erros — a resposta de sucesso segue inline
- [x] 1.4 Atualizar o docblock de `lib/nfe/resources/dto/service_invoice.rb` ("defines NO component schemas" → a resposta de sucesso é inline/sem schema nomeado; o modelo segue manuscrito)

## 2. DTO

- [x] 2.1 `Nfe::ServiceInvoice`: adicionar membros `base_tax_amount`, `iss_rate`, `iss_tax_amount` e `:raw` (anexados ao fim, `:raw` por último — convenção `ConsumerInvoice`); `from_api` popula `raw: payload`
- [x] 2.2 Criar `lib/nfe/resources/dto/service_invoice_borrower.rb` (`Data.define`: `id`, `name`, `federal_tax_number`, `email`, `phone_number`, `address`, `parent_id`, `raw`; `federal_tax_number` via `Company.stringify`; ponte Hash `#[]`/`#dig` delegando ao `raw`); `from_api` do `ServiceInvoice` hidrata `borrower` com ele
- [x] 2.3 Deprecar `pdf`/`xml` (`@deprecated` YARD → `download_pdf`/`download_xml`; membros mantidos)
- [x] 2.4 RBS: atualizar `sig/nfe/resources/dto/service_invoice.rbs` + criar `sig/nfe/resources/dto/service_invoice_borrower.rbs`

## 3. Alinhamento com o spec

- [x] 3.1 Spec RSpec de alinhamento (Psych) ancorado pelo path `/v1/companies/{company_id}/serviceinvoices/{id}` (NÃO por `operationId` — colisão `ServiceInvoices_idGet`): membros tipados (exceto `raw`/`pdf`/`xml`) ⊆ propriedades do schema; Borrower ⊆ sub-schema `borrower`
- [x] 3.2 Pinar no teste: fantasmas (`pdf`/`xml` ausentes do schema) e desvio `borrower.federalTaxNumber` int64 no spec vs String no DTO

## 4. Testes

- [x] 4.1 Atualizar "drops unknown keys" em `service_invoice_spec.rb` → chaves desconhecidas preservadas em `:raw` (payload completo)
- [x] 4.2 Unit: Borrower tipado + ponte Hash (`borrower["name"]`, `borrower.dig(...)`) + `federal_tax_number` String para fio Integer E String
- [x] 4.3 Unit: mapeamento dos 3 campos de ISS; `raw` presente em list/retrieve/cancel/issued (via `from_api`)
- [x] 4.4 `rake` completo limpo (spec + rubocop + steep + rbs + generate:check)
- [x] 4.5 (Opcional) Sonda ao vivo no retrieve confirmando serialização dos campos de ISS e shape do `borrower`

## 5. Docs & release

- [x] 5.1 Atualizar `docs/recursos/service-invoices.md` (campos tipados, `raw`, Borrower, deprecação pdf/xml) e a skill `nfeio-ruby-sdk` se citar os campos
- [x] 5.2 CHANGELOG (minor): `raw` + campos ISS + Borrower com ponte + deprecações + spec/gerado do `nf-servico-v1` — mensagens consistentes com o client-php (`expand-service-invoice-dto`)
