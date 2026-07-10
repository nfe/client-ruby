# Proposal: expand-service-invoice-dto (client-ruby)

## Why

O DTO `Nfe::ServiceInvoice` é 100% manuscrito e cobre **19 dos 44 campos** que a API devolve no retrieve de NFS-e (`GET /v1/companies/{company_id}/serviceinvoices/{id}`, schema inline em `openapi/nf-servico-v1.yaml`):

1. **Não há membro `:raw`** — `from_api` **descarta** chaves desconhecidas (comportamento testado em `spec/nfe/resources/dto/service_invoice_spec.rb`, "drops unknown keys"), jogando fora ~25 campos: toda a árvore de retenções (`issAmountWithheld`, `irAmountWithheld`, `pisAmountWithheld`, `cofinsAmountWithheld`, `csllAmountWithheld`, `inssAmountWithheld`, `othersAmountWithheld`, `amountWithheld`), `provider` (21 subcampos), `taxationType`, `location`, `approximateTax`, `externalId`, `rpsStatus`, `rpsType`, descontos/deduções etc. Esses dados ficam **inacessíveis** — nem tipados, nem via escape-hatch.
2. **2 campos-fantasma**: `pdf` e `xml` não existem na resposta do retrieve (sempre `nil`; os documentos vêm por `/pdf` e `/xml`).
3. **`borrower` é Hash cru** sem tipo — e `borrower.federalTaxNumber` é `integer int64` no spec, o que quebra com o CNPJ alfanumérico (IN RFB 2.229/2024).
4. **Faltam os 3 campos de ISS**: `baseTaxAmount`, `issRate`, `issTaxAmount` (todos `number/double` no spec).

Causa-raiz: o `nf-servico-v1.yaml` declara a resposta de **sucesso** do retrieve **inline** (sem schema nomeado em `components.schemas`), então o gerador (`rake generate` → `Nfe::Build::Generator`) não produz o modelo — não existe `Nfe::Generated::NfServicoV1::ServiceInvoice`. Nota de estado (2026-07-09): uma atualização local do yaml (working tree, não commitada) adicionou `components.schemas.ErrorsResource`, então o spec **deixa de ser pulado por inteiro** (passará a gerar um namespace só de erros; `rake generate` deve acompanhar esse commit ou `generate:check` quebra a CI — verificado). Isso **não** muda o gap desta change: a resposta de sucesso segue inline e o `ServiceInvoice` segue manuscrito. Esta change é a **mitigação do lado do SDK** (mesma sequência da change `expand-service-invoice-dto` do client-php) enquanto o conserto de origem — componentizar a resposta de sucesso no `nfe/docs` — não vem.

## What Changes

- **Adicionar membro `:raw`** ao `Nfe::ServiceInvoice`, populado com o payload completo no `from_api` (padrão já existente em `Nfe::ConsumerInvoice` — "preserved under raw for forward compatibility"). Como `from_api` é o único ponto de hidratação (list, retrieve, cancel, 201-issued), um único edit destrava os 44 campos em todas as leituras.
- **Tipar os 3 campos de ISS** (aditivo, anexados ao fim antes de `:raw`): `base_tax_amount`, `iss_rate`, `iss_tax_amount`. Os demais ~22 permanecem via `raw` (gradiente de valor — o Ruby já tem os campos de alto valor que o PHP precisou adicionar: `number`, `check_code`, `description`, `city_service_code`, `amount_net`).
- **DTO aninhado `Nfe::ServiceInvoiceBorrower`** (7 campos) com **ponte Hash**: membro `:raw` + `#[]`/`#dig` delegando ao Hash do fio, para que `invoice.borrower["name"]` (comportamento vivo hoje) continue funcionando enquanto `invoice.borrower.name` passa a existir. `federal_tax_number` tolerante a Integer OU String via o helper `Company.stringify` (preserva CNPJ alfanumérico). `provider` (21 subcampos) **não** é tipado — fica em `raw["provider"]`.
- **Teste de alinhamento YAML↔DTO** parseando o schema inline, **ancorado pelo path** `/v1/companies/{company_id}/serviceinvoices/{id}` — NÃO por `operationId` (colisão: `ServiceInvoices_idGet` aparece em `/{id}` E em `/external/{id}`). Precedente: `fix-account-webhooks-contract`. Pina os fantasmas (pdf/xml ausentes do schema) e o desvio `federalTaxNumber` int64 vs String no DTO.
- **Deprecar `pdf`/`xml`** (`@deprecated` YARD, membros mantidos — sempre `nil` no retrieve) apontando `download_pdf`/`download_xml`.
- **Atualizar RBS** (`sig/nfe/resources/dto/service_invoice.rbs` + sig novo do Borrower), o `service_invoice_spec.rb` ("drops unknown keys" → preservado em `:raw`), docs do recurso e a skill se citarem os campos.
- **Absorver a atualização do `openapi/nf-servico-v1.yaml`** (já no working tree: `ErrorsResource` em `components.schemas` + respostas 4xx/5xx tipadas) seguindo o fluxo documentado "commit specs and generated files together": rodar `rake generate` e commitar o namespace gerado (`lib/nfe/generated/nf_servico_v1/`, só erros) junto — sem isso `rake generate:check` quebra a CI (verificado). Corrigir as referências que ficam obsoletas: `openapi/README.md` (spec sai da lista de pulados) e o docblock do `service_invoice.rb` ("defines NO component schemas" → resposta de sucesso inline).

**Não faz parte** (ortogonal): componentizar a resposta de **sucesso** no `nfe/docs` (upstream) e mudanças no código do gerador.

## Capabilities

### New Capabilities

_(nenhuma)_

### Modified Capabilities

- `invoice-resources`: o requisito "Service invoice CRUD, email, downloads, and status" tem o cenário de retrieve ampliado (hidratação preserva o payload completo em `raw`); requisito novo para o shape do `ServiceInvoice` (gradiente tipado+raw, Borrower com ponte Hash, fantasmas deprecados, teste de alinhamento por path).
- `openapi-pipeline`: comportamento inalterado; o cenário "Spec without schemas produces nothing" troca o exemplo obsoleto (`nf-servico-v1.yaml` agora tem `components.schemas.ErrorsResource`; `cpf-api.yaml` permanece como exemplo).

## Impact

- **Código**: `lib/nfe/resources/dto/service_invoice.rb` (`:raw` + 3 membros + deprecations + docblock), novo `lib/nfe/resources/dto/service_invoice_borrower.rb`, `sig/nfe/resources/dto/**`; `openapi/nf-servico-v1.yaml` + saída de `rake generate` (`lib/nfe/generated/nf_servico_v1/**`, `sig/nfe/generated/nf_servico_v1/**`, `generated.rb`, `generated_marker.rb`) + `openapi/README.md`.
- **Testes**: alinhamento YAML↔DTO por path; hidratação (`raw` populado, campos novos, Borrower + ponte); "drops unknown keys" atualizado.
- **SemVer**: **minor** — tudo aditivo; `borrower` mantém leitura Hash pela ponte; `pdf`/`xml` deprecados (não removidos); membros novos anexados ao fim (`:raw` por último, convenção do `ConsumerInvoice`).
- **Natureza de ponte**: quando o `nfe/docs` componentizar a resposta (schema vira `$ref`), o `dig` por path do teste de alinhamento quebra → sinal para migrar ao modelo gerado com segurança.
- **Consistência cross-SDK**: mesma forma e nome da change do client-php (`expand-service-invoice-dto`); CHANGELOG coordenado.
