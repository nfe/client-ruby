# Design — add-lookup-resources

## Context

Os 8 recursos cobertos por esta change têm a personalidade mais variada do SDK Ruby v1:

- **CEP lookup** (`addresses`) é trivialmente um GET por código, com normalização de hífen.
- **CNPJ/CPF lookup** (`legal_entity_lookup`, `natural_person_lookup`) é GET por número com normalização forte de entrada (aceita `12.345.678/0001-90` e `12345678000190`) + validação de UF.
- **Tax calculation** (`tax_calculation`) é POST com payload denso item-a-item; a resposta é um breakdown de impostos por item (ICMS/ICMS-ST/PIS/COFINS/IPI/II + CFOP).
- **State taxes** (`state_taxes`) é CRUD completo por empresa.
- **Invoice queries** (`product_invoice_query`, `consumer_invoice_query`) são read-only por chave de acesso (44 dígitos), sem escopo de empresa.

Esta change é o **principal consumidor do host map** de `add-client-core`: 6 das 8 famílias batem em hosts dedicados fora de `api.nfe.io`. O foco do design é **fail-fast validation** na borda + **roteamento multi-host correto e travado por teste**.

Tudo é adaptado para Ruby idiomático: value objects são `Data.define` imutáveis; argumentos são keyword args com `snake_case`; downloads retornam `String` binária (`force_encoding(Encoding::ASCII_8BIT)`); o que no Node é `Promise`/`Buffer` vira retorno síncrono/`String`; erros são `raise` de classes tipadas (`Nfe::InvalidRequestError`, `Nfe::NotFoundError`, etc., definidas em `add-client-core`).

## Goals / Non-Goals

**Goals**
- 8 recursos com paridade método-por-método com o Node SDK (e PHP), adaptados a snake_case.
- Aceitar entrada formatada (CNPJ/CPF com pontuação, CEP com hífen, UF minúscula) e **normalizar antes do HTTP**, retornando o valor normalizado dos validadores.
- Confirmar roteamento multi-host: cada spec de recurso assertiona o host de saída via transporte mockado.
- Value objects gerados (`lib/nfe/generated/`) onde o gerador OpenAPI cobrir; hand-written em `lib/nfe/resources/dto/<family>/` onde o gen for esparso. NUNCA editar arquivos gerados à mão.
- `Nfe::DateNormalizer` para parâmetros de data: aceita `String` ISO ou objetos `Date`/`Time`/`DateTime`.
- Downloads (PDF/XML) retornam `String` binária crua, via o helper de download de `Nfe::Resources::AbstractResource`.

**Non-Goals**
- Validação de dígito verificador (Module-11) de CNPJ/CPF — o servidor valida; complexidade != ganho.
- CNPJ alfanumérico (v3) — fora do escopo v1 desta change; registrado como risco/evolução (R7).
- Builder fluente para o payload de `calculate` — `Hash` é suficiente; quem quer tipo usa o value object gerado.
- Caching de respostas de lookup — o caller decide; o SDK não tem camada de cache.
- Parser de OData `$filter` em `addresses.search` — repassado opaco como string para a API; sem parser local.
- Auto-paginação (`list_all`/iterator) em `state_taxes`/`tax_codes` — o caller escreve o loop; `ListResponse` carrega os cursores/páginas para isso.

## Decisions

### D1. Cada recurso valida no boundary, antes do HTTP, e usa o valor normalizado
**Decisão**: todo método público chama o validador apropriado (`Nfe::IdValidator.cnpj`, `.cpf`, `.cep`, `.state`, `.access_key`, `.company_id`, `.state_tax_id`) como primeira instrução. O validador **retorna a versão normalizada** (dígitos puros para tax numbers/CEP, UF maiúscula para estados) e é esse valor normalizado que entra no path.

```ruby
def get_basic_info(federal_tax_number, update_address: nil, update_city_code: nil)
  cnpj = Nfe::IdValidator.cnpj(federal_tax_number) # normaliza + valida 14 dígitos
  query = {}
  query[:updateAddress]  = update_address  unless update_address.nil?
  query[:updateCityCode] = update_city_code unless update_city_code.nil?
  hydrate(LegalEntityBasicInfoResponse, get("/v2/legalentities/basicInfo/#{cnpj}", query: query))
end
```

**Por quê**: paridade com Node + fail-fast com mensagem clara em pt-BR. Não confiamos em strings de entrada do usuário; erros de digitação falham localmente sem queimar uma chamada paga à API.

**Por quê retornar o normalizado** (e não só validar in-place): evita esquecer de normalizar e mandar `12.345.678/0001-90` no path. O validador é a única fonte da verdade da forma normalizada.

### D2. `Nfe::DateNormalizer` para inputs de data
**Decisão**: `Nfe::DateNormalizer.to_iso_date(input) -> String` retorna `"YYYY-MM-DD"`. Aceita:
- `String` que casa `/\A\d{4}-\d{2}-\d{2}\z/` **e** sobrevive a um roundtrip via `Date.iso8601` (rejeita `2026-13-45`);
- `Date`, `Time`, `DateTime` (via `.strftime("%Y-%m-%d")`, descartando o componente de hora).

Qualquer outra coisa (formato `15/01/1990`, mês/dia fora de faixa, tipo inesperado) levanta `Nfe::InvalidRequestError`.

```ruby
def get_status(federal_tax_number, birth_date)
  cpf  = Nfe::IdValidator.cpf(federal_tax_number)
  date = Nfe::DateNormalizer.to_iso_date(birth_date)
  hydrate(NaturalPersonStatusResponse, get("/v1/naturalperson/status/#{cpf}/#{date}"))
end
```

**Por quê**: devs Ruby alternam entre string ISO e objetos de data conforme o contexto; aceitar ambos elimina conversão na borda. Espelha o `string | Date` do Node e o `DateNormalizer::toIsoDate` do PHP.

**Alternativa rejeitada**: aceitar só `String`. Força o caller a formatar `Date` na mão — atrito desnecessário em Ruby, onde `date`/`time` são stdlib.

### D3. Hosts dedicados confirmados por teste (esta change é o exercitador do host map)
**Decisão**: cada spec de método em `legal_entity_lookup`, `natural_person_lookup`, `addresses`, `product_invoice_query`, `consumer_invoice_query`, `tax_calculation`, `tax_codes`, `state_taxes` assertiona que o host capturado pelo transporte mockado é o esperado.

```ruby
client = Nfe::Client.new(api_key: "k", transport: mock)
client.legal_entity_lookup.get_basic_info("12345678000190")
expect(mock.last_request.uri.to_s).to start_with("https://legalentity.api.nfe.io/v2/legalentities/basicInfo/")
```

Mapa de hosts (single source of truth em `Nfe::Configuration`, entregue por **add-client-core**):

| Família (`api_family`) | Host | Recursos desta change |
|---|---|---|
| `addresses` | `https://address.api.nfe.io/v2` (versão na base URL) | `addresses` |
| `legal-entity` | `https://legalentity.api.nfe.io` | `legal_entity_lookup` |
| `natural-person` | `https://naturalperson.api.nfe.io` | `natural_person_lookup` |
| `nfe-query` | `https://nfe.api.nfe.io` | `product_invoice_query` (v2), `consumer_invoice_query` (v1) |
| `cte` | `https://api.nfse.io` | `tax_calculation`, `tax_codes`, `state_taxes` |

**Por quê**: o multi-base-URL routing é um pilar de `add-client-core`; esta change é o consumidor mais agressivo. Travar o host no teste impede que um refactor do mapa quebre o roteamento silenciosamente.

### D4. `addresses` usa base URL com `/v2` embutido; `api_version` vazia
**Decisão**: a família `addresses` aponta para `https://address.api.nfe.io/v2`, então o `/v2` é parte da base URL — **não** do path. `AddressesResource#api_version` retorna `""` (string vazia) e os paths internos são `/addresses/...`. O `AbstractResource` (de `add-client-core`) compõe o full path tolerando `api_version` vazia sem gerar `//addresses`.

**Por quê**: espelha o `ADDRESS_API_BASE_URL = 'https://address.api.nfe.io/v2'` do Node. O recurso não deve hard-codear `/v2` no path porque isso duplicaria a versão.

### D5. `product_invoice_query` usa v2; `consumer_invoice_query` usa v1 + `/coupon/` — mesmo host
**Decisão**: ambos roteiam para `https://nfe.api.nfe.io` (família `nfe-query`), mas com paths divergentes confirmados no Node:

| Recurso | Path de retrieve | Path de download |
|---|---|---|
| `product_invoice_query` | `GET /v2/productinvoices/{access_key}` | `/v2/productinvoices/{access_key}.pdf` e `.xml`; eventos em `/v2/productinvoices/events/{access_key}` |
| `consumer_invoice_query` | `GET /v1/consumerinvoices/coupon/{access_key}` | `/v1/consumerinvoices/coupon/{access_key}.xml` |

Downloads de query usam o sufixo `.pdf` / `.xml` no path (não um sub-recurso) e devem mandar o header `Accept` correto (`application/pdf` / `application/xml`).

**Por quê**: os dois recursos compartilham host mas versões de API distintas. Hard-codear o path por recurso (em vez de um `api_version` único) é o caminho honesto, porque a versão **não** é uniforme por host aqui.

**Cross-reference**: `consumer_invoice_query.retrieve` devolve um `TaxCoupon` (CFe-SAT) — é **consulta** por chave. Não confundir com `consumer_invoices.create` (emissão NFC-e) de **add-invoice-resources**, que é escopado por empresa e vive em `api.nfse.io`.

### D6. Value objects: gerados quando possível, hand-written quando o gen for esparso
**Decisão**: para cada resposta, primeiro checar se o gerador OpenAPI emitiu o value object sob `lib/nfe/generated/<Spec>/`. Se sim, hidratar contra ele. Se o gen for esparso (specs de query/CPF costumam ser), criar `Data.define` hand-written em `lib/nfe/resources/dto/<family>/`.

Candidatos prováveis a hand-written (confirmar `ls lib/nfe/generated/<NS>` antes):
- `Nfe::Resources::Dto::Addresses::AddressLookupResponse` (`consulta-endereco` pode cobrir).
- `Nfe::Resources::Dto::NaturalPersonLookup::NaturalPersonStatusResponse` (spec de CPF é esparso).
- `Nfe::Resources::Dto::TaxCodes::TaxCodePaginatedResponse` (paginação 1-based: `current_page`, `total_pages`, `total_count`, `items`).
- `Nfe::Resources::Dto::ConsumerInvoiceQuery::TaxCoupon` + sub-objetos (`CouponIssuer`, `CouponBuyer`, `CouponTotal`, `CouponItem`, `CouponPayment`, etc.).
- `Nfe::Resources::Dto::StateTaxes::NfeStateTax`.
- `Nfe::Resources::Dto::LegalEntityLookup::*` (basicInfo / stateTax / stateTaxForInvoice).

Todos imutáveis via `Data.define`. **NUNCA** editar arquivos sob `lib/nfe/generated/` à mão (CI sync guard reclama).

**Por quê**: paralelo direto da decisão do PHP (DTOs hand-written em `src/Resource/Dto/`). Mantém os gerados puros e os complementos visíveis.

### D7. `tax_calculation.calculate` aceita `Hash` opaco; value object gerado é opcional
**Decisão**: `calculate(tenant_id, request)` aceita `request` como `Hash`. Validação local mínima: `tenant_id` não vazio, `request[:operation_type]`/`:operationType` presente, `request[:items]` array não vazio. PHPDoc/RBS recomendam construir `Nfe::Generated::CalculoImpostosV1::CalculateRequest` e passar `.to_h` para type-safety.

O `tenant_id` é URL-encodado no path: `POST /tax-rules/{tenant_id}/engine/calculate`. Host: `https://api.nfse.io` (família `cte`).

**Por quê**: paridade com Node (aceita objeto literal). O motor de cálculo evolui (RTC/IBS/CBS); forçar shape no cliente seria frágil. O SDK passa adiante e devolve o breakdown.

**Nota de validação**: o Node valida `issuer` e `recipient` obrigatórios; o PHP valida só `tenantId` + `items` + `operationType`. Adotamos o conjunto **mínimo do PHP** (tenant + operation_type + items não vazio) para não bloquear payloads válidos que o motor aceita — `issuer`/`recipient` ausentes viram 400 server-side com mensagem clara.

### D8. `tax_codes` é paginação page-style 1-based (distinta do cursor)
**Decisão**: os 4 métodos `list_*` aceitam `page_index:` (1-based, default da API se omitido) e `page_count:` (default 50 na API). A resposta carrega `current_page`, `total_pages`, `total_count`, `items`. Isso é **distinto** do cursor-style (`starting_after`/`ending_before`/`limit`) usado por `state_taxes` e pelos invoice resources.

**Por quê**: confirmado no Node (`TaxCodeListOptions { pageIndex, pageCount }`). Documentar em RBS/comentário que `tax_codes` é 1-based page-style — para o caller não confundir com o cursor das outras listas.

### D9. `state_taxes` é o único CRUD; envelopa o body como `{ state_tax: data }`
**Decisão**: `state_taxes` expõe `list` (cursor-style), `create`, `retrieve`, `update`, `delete`. `create` e `update` envolvem o body como `{ stateTax: <data> }` antes do POST/PUT (envelope canônico do Node `state-taxes.ts`). `delete` retorna `nil` (HTTP 200/204 sem corpo significativo). Host: `https://api.nfse.io` (família `cte`), paths `v2`.

Validação via `Nfe::IdValidator.company_id` + `Nfe::IdValidator.state_tax_id` (ambos de **add-client-core**).

**Por quê**: paridade exata com o Node. O envelope `{ stateTax: ... }` é aplicado pelo SDK — o caller passa só os campos.

### D10. `addresses.search` repassa `$filter` OData opaco
**Decisão**: `search(filter: nil)` repassa `filter` direto na query string como `$filter=...`. O SDK não parseia nem valida a expressão; o caller é responsável por montá-la e por escapar valores. URL-encoding da query é feito pelo transporte.

```ruby
client.addresses.search(filter: "city eq 'São Paulo'")
# => GET https://address.api.nfe.io/v2/addresses?$filter=city%20eq%20%27S%C3%A3o%20Paulo%27
```

**Por quê**: paridade com Node. Implementar parser OData seria over-reach. Filtro mal formado → 400 → `Nfe::InvalidRequestError` com payload, e o caller depura.

### D11. Downloads retornam `String` binária; usam o helper de `AbstractResource`
**Decisão**: `product_invoice_query.download_pdf` / `download_xml` e `consumer_invoice_query.download_xml` retornam `String` binária crua (`force_encoding(Encoding::ASCII_8BIT)`), via o helper `download(path, accept:)` de `Nfe::Resources::AbstractResource` (entregue por **add-client-core**). O helper manda o header `Accept` apropriado e devolve o corpo cru após validar 200.

**Por quê**: Ruby `String` é binary-safe; é o análogo natural do `Buffer` do Node. O caller decide se grava em disco (`File.binwrite`) ou faz stream. Mesma decisão dos downloads de invoice em **add-invoice-resources**.

**Dependência**: o helper `download` é compartilhado e vem de **add-client-core**.

### D12. Extensão de `IdValidator` (cep/state/cnpj/cpf) coexiste com a base
**Decisão**: `Nfe::IdValidator` (módulo de funções de módulo / métodos de classe, em **add-client-core**) ganha 4 validadores nesta change:
- `cep(value) -> String` — normaliza para 8 dígitos; rejeita comprimento != 8.
- `state(value) -> String` — UF maiúscula; aceita as 29 (27 UFs + `EX` + `NA`); rejeita o resto.
- `cnpj(value) -> String` — 14 dígitos numéricos (v1).
- `cpf(value) -> String` — 11 dígitos numéricos.

`access_key`, `company_id`, `state_tax_id` já existem em **add-client-core** e são reusados. **add-invoice-resources** adiciona `invoice_id`/`event_key` em métodos disjuntos — sem conflito de arquivo se ambas as changes editarem `id_validator.rb` (métodos distintos).

**Por quê**: centraliza toda normalização de identificador fiscal num único módulo testável. Mensagens em pt-BR.

## Risks / Trade-offs

| Risco | Mitigação |
|---|---|
| Hosts dedicados mudam (`legalentity.api.nfe.io` → outro) | `Nfe::Configuration` host map é o único ponto a ajustar; specs travam o host esperado por recurso; smoke test pega antes do GA |
| Specs OpenAPI esparsos não cobrem respostas críticas (CPF, query, coupon) | Value objects hand-written em `lib/nfe/resources/dto/<family>/`; documentar quais foram hand-written; migrar quando o gen evoluir |
| Payload de `calculate` muda no servidor (RTC/IBS/CBS) | Aceitamos `Hash` opaco — SDK não força shape no cliente, só repassa; risco fica com o caller; RBS recomenda o value object gerado |
| OData `$filter` mal formado quebra `addresses.search` | API retorna 400 → `Nfe::InvalidRequestError` com payload; caller depura |
| Rate limit / cobrança por chamada em lookup CNPJ/CPF esgota billing | Retry de `add-client-core` honra `Retry-After`; comentário/RBS avisam do custo |
| `DateNormalizer` frouxo aceita data inválida (`2026-13-45`) | Regex estrita `/\A\d{4}-\d{2}-\d{2}\z/` + roundtrip `Date.iso8601` que rejeita mês/dia fora de faixa |
| Confusão entre `consumer_invoice_query` (consulta) e `consumer_invoices` (emissão) | Documentado em proposal + spec + cross-reference a **add-invoice-resources**; hosts e versões distintos deixam claro |
| CNPJ alfanumérico (jul/2026) incompatível com `IdValidator::cnpj` numérico v1 | v1 desta change é numérico-only por design (endpoints v1/v2 não mudam); alfanumérico vive em v3 — evolução futura (R7), não coagir para Integer |

## Resolved (durante recon — grounding nos arquivos do Node SDK)

### R1. Hosts canônicos confirmados; specs PHP divergentes ignorados
**Achado**: os arquivos do Node SDK definem os hosts canônicos em constantes:
- `addresses.ts:17` → `ADDRESS_API_BASE_URL = 'https://address.api.nfe.io/v2'`
- `legal-entity-lookup.ts:29` → `LEGAL_ENTITY_API_BASE_URL = 'https://legalentity.api.nfe.io'`
- `natural-person-lookup.ts:20` → `NATURAL_PERSON_API_BASE_URL = 'https://naturalperson.api.nfe.io'`
- `product-invoice-query.ts:21` → `NFE_QUERY_API_BASE_URL = 'https://nfe.api.nfe.io'`
- `tax-calculation.ts` / `tax-codes.ts` / `state-taxes.ts` → host `api.nfse.io` (família `cte`)

As deltas de spec do PHP listavam `api-legalentity.nfe.io` / `api-naturalperson.nfe.io` — **divergência conhecida e incorreta**. O `client-core` spec do PHP e o Node concordam no `*.api.nfe.io`. **Decisão**: usar `legalentity.api.nfe.io` e `naturalperson.api.nfe.io`.

### R2. `product_invoice_query` usa v2; `consumer_invoice_query` usa v1 + `/coupon/`
**Achado** (paths exatos do Node):
- `product-invoice-query.ts:108` → `/v2/productinvoices/{accessKey}`; `:133` → `.pdf`; `:159` → `.xml`; `:189` → `/v2/productinvoices/events/{accessKey}`
- `consumer-invoice-query.ts:100` → `/v1/consumerinvoices/coupon/{accessKey}`; `:125` → `.xml`

**Decisão**: paths hard-coded por recurso (D5). `consumer_invoice_query.retrieve` devolve `TaxCoupon`.

### R3. `tax_codes` é page-style 1-based
**Achado**: `tax-codes.ts:25-39` monta `pageIndex`/`pageCount` na query; doc diz "1-based, default 1" e "default 50". Resposta com `currentPage`/`totalPages`/`totalCount`/`items`. Distinto do cursor de `state-taxes`.
**Decisão**: D8.

### R4. `state_taxes.create`/`update` envelopam `{ stateTax: data }`
**Achado**: `state-taxes.ts:169` (`{ stateTax: data }` no POST) e `:237` (idem no PUT). `list` usa `startingAfter`/`endingBefore`/`limit` (cursor). `delete` retorna void.
**Decisão**: D9.

### R5. `tax_calculation.calculate` — validação do Node vs PHP
**Achado**: `tax-calculation.ts:37-57` valida `issuer`, `recipient`, `operationType`, `items` não vazio + `tenantId` não vazio. O PHP valida só `tenantId` + `operationType` + `items`. Path: `/tax-rules/{tenantId}/engine/calculate` com `tenantId` URL-encodado (`:178`).
**Decisão**: D7 — adotar o conjunto mínimo do PHP (tenant + operation_type + items), deixando issuer/recipient para o servidor validar.

### R6. `IdValidator::state` aceita 29 valores (27 UFs + EX + NA)
**Achado**: `legal-entity-lookup.ts:32-37` define o `Set` com `AC..TO` + `EX` + `NA` (29 valores). `validateState` normaliza para uppercase e rejeita fora do set. `validateFederalTaxNumber` exige 14 dígitos após `replace(/\D/g,'')`; `validateCpf` exige 11.
**Decisão**: D12 — `IdValidator.state` aceita os 29; `cnpj` 14 dígitos; `cpf` 11 dígitos; `cep` 8 dígitos.

### R7. CNPJ alfanumérico é v3 — fora do escopo v1
**Achado**: a IN RFB 2.229/2024 (vigente jul/2026) permite letras nas 12 primeiras posições do CNPJ; entregue via APIs **v3** (`consulta-cnpj-v3` etc.). As famílias v1/v2 desta change permanecem numéricas.
**Decisão**: `IdValidator::cnpj` v1 valida 14 dígitos numéricos. Não coagir para Integer (deixar como `String` desde já evita a armadilha do Node `validateCNPJ`), mas o suporte alfanumérico real fica para uma evolução sobre endpoints v3. Registrado como risco.
