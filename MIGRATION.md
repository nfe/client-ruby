# Guia de migração — `0.x` → `1.0`

> ⚠️ A `v1.0.0` é uma **reescrita greenfield, sem camada de compatibilidade**.
> Nenhum símbolo da série `0.x` foi mantido. Não existe modo de transição, alias
> ou shim: o código `0.x` **não compila** contra a `1.0`. Migre de forma
> deliberada, recurso a recurso.

A `0.x` está **congelada** no branch `0.x-legacy` (sem backports — correções e
novos recursos só na `1.0+`). O branch `master` passa a ser a `v1`.

## Sumário

A `1.0` substitui o estado global por instância (`Nfe.api_key`,
`Nfe::ServiceInvoice.company_id`) por um **cliente único** (`Nfe::Client`),
remove a dependência `rest-client` (agora **zero dependências de runtime**,
apenas a stdlib), exige **Ruby 3.2+**, troca os objetos dinâmicos por
**value objects imutáveis** (`Data.define`, `snake_case`) e introduz uma
**hierarquia de erros tipada** sob `Nfe::Error`. A emissão de notas passa a ter
um contrato **assíncrono explícito** (resposta `202` → `Pending`/`Issued`).

---

## 1. Visão geral das mudanças

| Tema | `0.x` (legado) | `1.0` |
|---|---|---|
| Entrada | API global: `Nfe.api_key("...")` + estado por classe | Cliente único: `Nfe::Client.new(api_key: "...")` |
| Configuração | `Nfe.configure { \|c\| c.url = ...; c.user_agent = ... }` | argumentos do construtor de `Nfe::Client` / `Nfe::Configuration` |
| Escopo de empresa | `Nfe::ServiceInvoice.company_id("...")` (estado mutável por classe) | `company_id:` por chamada |
| Roteamento de host | uma única `configuration.url` global | host **roteado por recurso** (multi-host automático) |
| Segunda chave de API | inexistente | `data_api_key:` com fallback para `api_key` |
| HTTP | dependência `rest-client` | zero deps — `Net::HTTP` da stdlib |
| Modelos | `NfeObject` dinâmico (`method_missing`, `reflesh_object`) | value objects imutáveis (`Data.define`), `snake_case` |
| Ruby | 2.x | 3.2 / 3.3 / 3.4 |
| Erros | `Nfe::NfeError` único (`http_status`, `json_message`) | hierarquia tipada sob `Nfe::Error` |
| Emissão | `create` retornava o objeto (sem distinção de `202`) | `create` retorna `*Pending` (202) **ou** `*Issued` (201) |
| Downloads | `download(id, :pdf).body` (objeto RestClient) | `String` binária (`ASCII-8BIT`) — exceto `product_invoices` (→ `NfeFileResource`) |
| Webhooks | esquema legado documentado (`X-NFe-Signature` / SHA-256) — **errado** | `X-Hub-Signature` + HMAC-SHA1 sobre os bytes crus |
| Thread-safety | estado global compartilhado (não seguro) | um `Nfe::Client` é seguro para compartilhar entre threads |

---

## 2. Instalação

Mudança de major — quebra intencional.

```ruby
# 0.x — Gemfile
gem "nfe-io", "~> 0.3"

# 1.0 — Gemfile
gem "nfe-io", "~> 1.0"
```

```ruby
# require permanece igual
require "nfe-io"   # ou require "nfe"
```

A `1.0` **não declara nenhuma dependência de runtime**. As bibliotecas
`rest-client` e `json` (gem) deixam de ser exigidas; a `1.0` usa apenas a
biblioteca padrão: `net/http`, `json`, `openssl`, `uri`, `securerandom`,
`stringio`, `time`, `zlib`, `cgi`, `date`, `base64`.

## 3. Versão do Ruby

| | `0.x` | `1.0` |
|---|---|---|
| Ruby mínimo | 2.x | **3.2** (`required_ruby_version = ">= 3.2"`) |
| Testado em CI | — | 3.2, 3.3, 3.4 |

A `1.0` usa `Data.define` (Ruby 3.2+), métodos de endpoint de uma linha
(`def x = ...`) e argumentos nomeados de forma generalizada. Não há
compatibilidade com Ruby 2.x.

---

## 4. Configuração

### 4.1 Chave de API e cliente

Na `0.x`, a chave era um estado **global de processo** e a empresa um estado
**mutável por classe**. Na `1.0`, ambos são explícitos: a chave vai no
construtor do `Nfe::Client` e a empresa em cada chamada.

```ruby
# 0.x — estado global + estado por classe
Nfe.api_key("c73d49f9649046eeba36dcf69f6334fd")
Nfe::ServiceInvoice.company_id("55df4dc6b6cd9007e4f13ee8")

# 1.0 — cliente único; nenhum estado global
client = Nfe::Client.new(api_key: "c73d49f9649046eeba36dcf69f6334fd")
```

Construtor completo (todos os argumentos são nomeados, com os defaults reais):

```ruby
client = Nfe::Client.new(
  api_key: "...",          # chave principal; fallback ENV NFE_API_KEY
  data_api_key: nil,       # chave de dados; fallback ENV NFE_DATA_API_KEY
  environment: :production, # :production (default) ou :development — SÍMBOLO
  timeout: 30,             # read timeout (segundos)
  max_retries: 3,          # tentativas após a inicial
  logger: nil,             # objeto com #info/#warn/#error
  user_agent_suffix: nil   # sufixo anexado ao User-Agent do SDK
)
```

> **`environment:` seleciona a CHAVE, não a URL.** `:production` e `:development`
> apontam para os MESMOS endpoints; o que diferencia o ambiente é a chave de API
> em uso. Não existe "URL de sandbox". É um **símbolo** (`:production`), não uma
> string.

#### Fallback por variável de ambiente

A chave pode vir do argumento **ou** do ambiente — o argumento explícito sempre
vence; um valor vazio é tratado como ausente.

```ruby
ENV["NFE_API_KEY"]      # usado por api_key quando o argumento é nil/vazio
ENV["NFE_DATA_API_KEY"] # usado por data_api_key quando o argumento é nil/vazio
```

#### Configuração avançada

Argumentos que não estão no atalho do `Client` (como `open_timeout`,
`base_url_overrides`, `ca_file`, `ca_path`, `proxy`) vivem em
`Nfe::Configuration`. Monte a configuração e injete-a:

```ruby
config = Nfe::Configuration.new(
  api_key: "...",
  open_timeout: 10,                                 # connect timeout (s)
  base_url_overrides: { main: "https://api.exemplo" }, # escape hatch por família
  ca_file: "/caminho/ca-bundle.crt",                # ADICIONA CAs ao trust store
  proxy: "http://proxy.interno:3128"
)
client = Nfe::Client.new(configuration: config)
# quando configuration: é passado, os demais atalhos do Client são ignorados.
```

> **TLS:** `ca_file`/`ca_path` só **adicionam/substituem** o bundle de CAs usado
> para verificar o servidor. **Não existe** API para desativar a verificação do
> peer (sem `VERIFY_NONE`, sem `insecure_ssl`).

### 4.2 Configuração global → por instância

| `0.x` | `1.0` |
|---|---|
| `Nfe.api_key("...")` | `Nfe::Client.new(api_key: "...")` |
| `Nfe.configure { \|c\| c.url = "..." }` | `Nfe::Configuration.new(base_url_overrides: { ... })` |
| `Nfe.configure { \|c\| c.user_agent = "..." }` | `Nfe::Client.new(user_agent_suffix: "...")` |
| `Nfe.configuration` / `Nfe.access_keys` | (removidos — sem estado global) |
| `Nfe::Configuration#url` (uma URL única) | host roteado por recurso (ver §4.4) |

### 4.3 Escopo de empresa: por classe → por chamada

```ruby
# 0.x — estado mutável por classe (não seguro entre threads)
Nfe::ServiceInvoice.company_id("55df4dc6b6cd9007e4f13ee8")
Nfe::ServiceInvoice.create(params)

# 1.0 — company_id é argumento de cada chamada
client.service_invoices.create(company_id: "55df4dc6b6cd9007e4f13ee8", data: { ... })
```

### 4.4 URL global → roteamento por recurso

Na `0.x` havia uma única `configuration.url` (`https://api.nfe.io`). Na `1.0`
**cada recurso declara sua família** e o host é resolvido automaticamente — você
não monta mais URLs.

| Família / host | Recursos roteados |
|---|---|
| `https://api.nfe.io` (`/v1`) | `service_invoices`, `companies`, `legal_people`, `natural_people`, `webhooks`, `service_invoices_rtc` |
| `https://api.nfse.io` (`/v2`) | `product_invoices`, `consumer_invoices`, `transportation_invoices`, `inbound_product_invoices`, `tax_calculation`, `tax_codes`, `state_taxes`, `product_invoices_rtc` |
| `https://address.api.nfe.io/v2` | `addresses` |
| `https://legalentity.api.nfe.io` | `legal_entity_lookup` |
| `https://naturalperson.api.nfe.io` | `natural_person_lookup` |
| `https://nfe.api.nfe.io` | `product_invoice_query`, `consumer_invoice_query` |

Para sobrescrever um host (ambiente de testes, proxy reverso), use
`base_url_overrides:` em `Nfe::Configuration` (chave = símbolo da família).

### 4.5 Segunda chave de API (`data_api_key`)

Novidade da `1.0`. As **famílias de dados** preferem `data_api_key` e caem para
`api_key` quando ela não é informada; todas as outras usam `api_key`.

```ruby
client = Nfe::Client.new(api_key: "EMISSAO", data_api_key: "CONSULTA")
```

Famílias que usam `data_api_key` (com fallback para `api_key`):

- `addresses` (consulta de endereços)
- `legal_entity_lookup` (consulta de pessoa jurídica)
- `natural_person_lookup` (consulta de pessoa física)
- `product_invoice_query` e `consumer_invoice_query` (consulta de NF-e/NFC-e)

> ⚠️ A família `:cte` (`api.nfse.io` — emissão de NF-e/NFC-e/CT-e + tax-rules /
> tax-codes / state-taxes) usa a **`api_key` principal** e **não** é uma família
> de dados. Isso é uma divergência deliberada do SDK Node (que roteia
> `api.nfse.io` pela cadeia de fallback da chave de dados) — documentada em
> `lib/nfe/configuration.rb`.

---

## 5. Mapeamento de classes (`0.x` → acessores da `1.0`)

Na `0.x` você chamava métodos de classe diretamente (`Nfe::ServiceInvoice`,
`Nfe::Company`, ...). Na `1.0` tudo passa pelos **acessores `snake_case`**,
preguiçosos e memoizados, do `Nfe::Client`.

| Classe `0.x` | Acessor `1.0` |
|---|---|
| `Nfe::ServiceInvoice` | `client.service_invoices` |
| `Nfe::Company` | `client.companies` |
| `Nfe::NaturalPeople` | `client.natural_people` |
| `Nfe::LegalPeople` | `client.legal_people` |
| `Nfe::NfeObject` (base dinâmica) | value objects imutáveis (`Nfe::ServiceInvoice`, `Nfe::Company`, ... — apenas leitura) |
| `Nfe::NfeError` | hierarquia `Nfe::Error` (ver §10) |

A `1.0` expõe **19 acessores** (17 canônicos + 2 addons RTC), muito além das
classes da `0.x`:

```
service_invoices            product_invoice_query     legal_entity_lookup
product_invoices            consumer_invoice_query    natural_person_lookup
consumer_invoices           companies                 tax_calculation
transportation_invoices     legal_people              tax_codes
inbound_product_invoices    natural_people            state_taxes
webhooks                    addresses
service_invoices_rtc        product_invoices_rtc       (addons RTC)
```

> ⚠️ Note a colisão de nomes: na `0.x`, `Nfe::ServiceInvoice` e `Nfe::Company`
> eram classes **ativas** (com métodos de criação). Na `1.0`, `Nfe::ServiceInvoice`
> e `Nfe::Company` são apenas **value objects de leitura**; o comportamento mora
> nos acessores `client.service_invoices` / `client.companies`.

---

## 6. Mapeamento de métodos por recurso

As notações abaixo refletem as assinaturas reais implementadas. Na `0.x`, os
recursos compartilhavam operações genéricas (`ApiOperations::Create`, `List`,
`Retrieve`, `Cancel`, `Update`, `Download`). Na `1.0`, cada método é explícito.

### 6.1 Service invoices (NFS-e) — `client.service_invoices`

| `0.x` | `1.0` |
|---|---|
| `Nfe::ServiceInvoice.create(params)` | `client.service_invoices.create(company_id:, data:, idempotency_key: nil, request_options: nil)` |
| `Nfe::ServiceInvoice.list_all(params)` | `client.service_invoices.list(company_id:, **options)` |
| `Nfe::ServiceInvoice.retrieve(id)` | `client.service_invoices.retrieve(company_id:, invoice_id:)` |
| `Nfe::ServiceInvoice.cancel(id)` | `client.service_invoices.cancel(company_id:, invoice_id:)` |
| `Nfe::ServiceInvoice.update(...)` | `client.service_invoices.send_email(company_id:, invoice_id:)` (e demais ações dedicadas) |
| `Nfe::ServiceInvoice.download(id, :pdf)` | `client.service_invoices.download_pdf(company_id:, invoice_id: nil)` |
| `Nfe::ServiceInvoice.download(id, :xml)` | `client.service_invoices.download_xml(company_id:, invoice_id: nil)` |
| — (sem equivalente) | `client.service_invoices.get_status(company_id:, invoice_id:)` → `StatusResult` |

Opções de `list`: `page_index`, `page_count`, `issued_begin`, `issued_end`,
`created_begin`, `created_end`, `has_totals` (paginação **page-style**).
`download_pdf`/`download_xml` com `invoice_id: nil` baixam o **ZIP** da empresa.

### 6.2 Companies — `client.companies`

| `0.x` | `1.0` |
|---|---|
| `Nfe::Company.create(params)` | `client.companies.create(data)` |
| `Nfe::Company.list_all(params)` | `client.companies.list(page_index: 0, page_count: 100)` |
| — | `client.companies.list_all` / `client.companies.list_each` (auto-paginação) |
| `Nfe::Company.retrieve(id)` | `client.companies.retrieve(company_id)` |
| `Nfe::Company.update(...)` | `client.companies.update(company_id, data)` |
| `Nfe::Company` + `ApiOperations::Delete` (`delete`) | `client.companies.remove(company_id)` → `{ deleted: true, id: }` |
| — | `client.companies.find_by_tax_number(tax_number)` |
| — | `client.companies.find_by_name(name)` |

Certificado digital (novo na `1.0`):

```ruby
client.companies.validate_certificate(file:, password:)              # local, sem HTTP
client.companies.upload_certificate(company_id, file:, password:, filename: nil)
client.companies.replace_certificate(company_id, file:, password:, filename: nil) # alias de upload
client.companies.get_certificate_status(company_id)
client.companies.check_certificate_expiration(company_id, threshold_days: 30)
client.companies.get_companies_with_certificates
client.companies.get_companies_with_expiring_certificates(threshold_days: 30)
```

> ⚠️ **`delete` virou `remove`.** Em `companies`, a remoção chama-se `#remove`
> (paridade com os SDKs Node/PHP), não `#delete`.

### 6.3 Legal people (PJ) — `client.legal_people`

| `0.x` | `1.0` |
|---|---|
| `Nfe::LegalPeople.company_id(id)` + `list_all` | `client.legal_people.list(company_id)` |
| `Nfe::LegalPeople.retrieve(id)` | `client.legal_people.retrieve(company_id, legal_person_id)` |
| — (não existia na `0.x`) | `client.legal_people.create(company_id, data)` |
| — | `client.legal_people.update(company_id, legal_person_id, data)` |
| — | `client.legal_people.delete(company_id, legal_person_id)` |
| — | `client.legal_people.create_batch(company_id, list)` (sequencial) |
| — | `client.legal_people.find_by_tax_number(company_id, federal_tax_number)` |

### 6.4 Natural people (PF) — `client.natural_people`

| `0.x` | `1.0` |
|---|---|
| `Nfe::NaturalPeople.company_id(id)` + `list_all` | `client.natural_people.list(company_id)` |
| `Nfe::NaturalPeople.retrieve(id)` | `client.natural_people.retrieve(company_id, natural_person_id)` |
| — | `client.natural_people.create(company_id, data)` |
| — | `client.natural_people.update(company_id, natural_person_id, data)` |
| — | `client.natural_people.delete(company_id, natural_person_id)` |
| — | `client.natural_people.create_batch(company_id, list)` |
| — | `client.natural_people.find_by_tax_number(company_id, federal_tax_number)` |

### 6.5 Recursos novos na `1.0` (sem equivalente na `0.x`)

Product invoices (NF-e) — `client.product_invoices`:

```ruby
create(company_id:, data:, idempotency_key: nil, request_options: nil)
create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)
list(company_id:, environment:, **options)   # environment: "Production"/"Test" OBRIGATÓRIO
retrieve(company_id:, invoice_id:)
cancel(company_id:, invoice_id:, reason: nil)
list_items(company_id:, invoice_id:, limit: nil, starting_after: nil)
list_events(company_id:, invoice_id:, limit: nil, starting_after: nil)
send_correction_letter(company_id:, invoice_id:, reason:)  # reason 15..1000 chars
disable(company_id:, invoice_id:, reason: nil)
disable_range(company_id:, data:)
download_pdf / download_xml / download_rejection_xml / download_epec_xml  # → NfeFileResource (URI)
download_correction_letter_pdf / download_correction_letter_xml          # → NfeFileResource (URI)
```

Consumer invoices (NFC-e) — `client.consumer_invoices`: `create`,
`create_with_state_tax`, `list`, `retrieve`, `cancel`, `list_items`,
`list_events`, `disable_range`, `download_pdf`, `download_xml`,
`download_rejection_xml`. (Sem `send_correction_letter`, `download_epec_xml` ou
`disable` por documento — restrições da legislação para NFC-e.)

Transportation invoices (CT-e recebidos) — `client.transportation_invoices`:
`enable`, `disable`, `get_settings`, `retrieve(company_id:, access_key:)`,
`download_xml`, `get_event`, `download_event_xml`.

Inbound product invoices (NF-e recebidas) — `client.inbound_product_invoices`:
`enable_auto_fetch`, `disable_auto_fetch`, `get_settings`, `get_details`,
`get_product_invoice_details`, `get_event_details`,
`get_product_invoice_event_details`, `get_xml`, `get_event_xml`, `get_pdf`,
`get_json`, `manifest(company_id:, access_key:, tp_event: 210210)`,
`reprocess_webhook`.

Consultas — `client.product_invoice_query`: `retrieve(access_key)`,
`download_pdf(access_key)`, `download_xml(access_key)`,
`list_events(access_key)`. `client.consumer_invoice_query`:
`retrieve(access_key)`, `download_xml(access_key)`.

Lookups (famílias de dados):

```ruby
client.addresses.lookup_by_postal_code(cep)
client.addresses.lookup_by_term(term)
client.addresses.search(filter: nil)
client.legal_entity_lookup.get_basic_info(cnpj, update_address: nil, update_city_code: nil)
client.legal_entity_lookup.get_state_tax_info(state, cnpj)
client.legal_entity_lookup.get_state_tax_for_invoice(state, cnpj)
client.legal_entity_lookup.get_suggested_state_tax_for_invoice(state, cnpj)
client.natural_person_lookup.get_status(cpf, birth_date)
```

Fiscais (família `:cte`):

```ruby
client.tax_calculation.calculate(tenant_id, request)              # request: Hash
client.tax_codes.list_operation_codes(page_index: nil, page_count: nil)
client.tax_codes.list_acquisition_purposes(...)
client.tax_codes.list_issuer_tax_profiles(...)
client.tax_codes.list_recipient_tax_profiles(...)
client.state_taxes.list(company_id, starting_after: nil, ending_before: nil, limit: nil)
client.state_taxes.create(company_id, data)
client.state_taxes.retrieve(company_id, state_tax_id)
client.state_taxes.update(company_id, state_tax_id, data)
client.state_taxes.delete(company_id, state_tax_id)
```

RTC (Reforma Tributária do Consumo) — addons da `1.0`:
`client.service_invoices_rtc` (`create`, `retrieve`, `cancel`,
`download_cancellation_xml`) e `client.product_invoices_rtc` (mesmo conjunto do
`product_invoices`). O layout RTC é selecionado pela **presença do grupo
`ibsCbs`** (NFS-e) ou `items[].tax.IBSCBS` (NF-e/NFC-e) no payload — mesmo
endpoint dos recursos clássicos, sem header/param discriminador.

> ⚠️ **`list` de product invoices exige `environment:`.** Em
> `client.product_invoices.list` e `client.product_invoices_rtc.list`,
> `environment:` é uma **String separada** (`"Production"`/`"Test"`),
> **distinta** do `environment:` do `Client` (que é um símbolo e seleciona a
> chave). Omiti-la levanta `Nfe::InvalidRequestError`.

---

## 7. Remoção do `rest-client`

A `0.x` dependia da gem `rest-client`; a `1.0` usa `Net::HTTP` da stdlib. Toda
exceção do `rest-client` que vazava do SDK desaparece.

| `0.x` (`rest-client`) | `1.0` |
|---|---|
| `RestClient::Exception` (rede/conexão) | `Nfe::ApiConnectionError` |
| timeout de conexão/leitura | `Nfe::TimeoutError` (subclasse de `ApiConnectionError`) |
| `RestClient::ExceptionWithResponse` (HTTP 4xx/5xx) | subclasse de `Nfe::Error` por status (ver §10) |
| `request.execute` retornando o objeto-resposta | objetos hidratados (`Data.define`) ou bytes (downloads) |

```ruby
# 0.x
begin
  Nfe::ServiceInvoice.create(params)
rescue RestClient::Exception => e
  # tratar erro de rede/HTTP
end

# 1.0
begin
  client.service_invoices.create(company_id:, data:)
rescue Nfe::ApiConnectionError => e   # rede (inclui TimeoutError)
  # ...
rescue Nfe::Error => e                # qualquer erro do SDK
  # ...
end
```

---

## 8. Tratamento de erros

A `0.x` tinha um único `Nfe::NfeError(http_status, json_message, http_message,
message)`. A `1.0` traz uma **hierarquia tipada** sob `Nfe::Error` — capture a
base para pegar toda a família, ou subclasses específicas para tratar casos.

```ruby
begin
  client.service_invoices.create(company_id:, data:)
rescue Nfe::RateLimitError => e
  sleep(e.retry_after || 5); retry
rescue Nfe::InvalidRequestError => e
  logger.warn(e.to_h)   # to_h é seguro para log (sem corpo/headers crus)
rescue Nfe::Error => e
  # rede comum: status_code, request_id, error_code, response_body, response_headers
end
```

| Classe `1.0` | Status HTTP | Quando |
|---|---|---|
| `Nfe::Error` | — | base de toda a hierarquia |
| `Nfe::AuthenticationError` | 401 | chave ausente ou inválida |
| `Nfe::AuthorizationError` | 403 | chave válida, mas sem permissão |
| `Nfe::InvalidRequestError` | 400 / 422 | requisição malformada ou inválida |
| `Nfe::NotFoundError` | 404 | recurso inexistente |
| `Nfe::ConflictError` | 409 | conflito com o estado atual |
| `Nfe::RateLimitError` | 429 | excesso de requisições (`#retry_after`) |
| `Nfe::ServerError` | 5xx | falha do servidor |
| `Nfe::ApiConnectionError` | — | falha de rede (DNS, conexão, TLS, reset) |
| `Nfe::TimeoutError` | — | timeout (subclasse de `ApiConnectionError`) |
| `Nfe::SignatureVerificationError` | — | assinatura de webhook inválida ou payload não-JSON |
| `Nfe::ConfigurationError` | — | SDK mal configurado (chave ausente, `environment` inválido) — antes de qualquer HTTP |
| `Nfe::InvoiceProcessingError` | — | resposta `202` sem `Location` utilizável |

Atributos disponíveis em erros derivados de resposta: `status_code`,
`request_id`, `error_code`, `response_body`, `response_headers`. O método
`#to_h` é **seguro para log** (omite `response_body`/`response_headers`, que
podem conter segredos/PII).

> ⚠️ Nomes que **não existem**: `Nfe::ConnectionError`, `Nfe::ValidationError`,
> `Nfe::PollingTimeoutError`. Use os nomes da tabela acima.

---

## 9. Respostas `202` (emissão assíncrona)

Na `0.x`, `create` simplesmente devolvia o objeto, sem distinguir emissão
síncrona de assíncrona. Na `1.0` o contrato é explícito: `create` retorna um
**resultado discriminado**.

- **HTTP 202** → `*Pending` (`invoice_id`, `location`; `pending? == true`,
  `issued? == false`). A nota está enfileirada; o `invoice_id` vem do header
  `Location`.
- **HTTP 201/200** → `*Issued` (`resource`; `issued? == true`,
  `pending? == false`). A nota foi materializada na hora.

(Recursos: `ServiceInvoicePending`/`ServiceInvoiceIssued`,
`ProductInvoicePending`/`ProductInvoiceIssued`, e as variantes Consumer e RTC.)

```ruby
result = client.service_invoices.create(company_id:, data:)

case result
in Nfe::Resources::ServiceInvoicePending => pending
  # acompanhar via polling (ver abaixo)
in Nfe::Resources::ServiceInvoiceIssued => issued
  nota = issued.resource
end
```

### Loop de polling

Não há `create_and_wait`/`create_batch` na `1.0` (ver §12). Faça o polling
manualmente com `Nfe::FlowStatus.terminal?`:

```ruby
result = client.service_invoices.create(company_id:, data:)

if result.pending?
  invoice = nil
  loop do
    invoice = client.service_invoices.retrieve(
      company_id:, invoice_id: result.invoice_id
    )
    break if Nfe::FlowStatus.terminal?(invoice.flow_status)
    sleep 2
  end
  # invoice.flow_status ∈ Issued | IssueFailed | Cancelled | CancelFailed
end
```

Estados **terminais** (param o polling): `Issued`, `IssueFailed`, `Cancelled`,
`CancelFailed`. Para `service_invoices` há ainda o atalho
`client.service_invoices.get_status(company_id:, invoice_id:)`, que devolve um
`StatusResult` com `#complete?` e `#failed?` (derivado de `retrieve`, sem HTTP
extra além do `retrieve`).

---

## 10. Verificação de webhook

> ⚠️ A documentação **antiga** falava em header `X-NFe-Signature`, HMAC-**SHA256**
> e Base64. **Isso está errado** para o SDK `1.0` (e para o que a NFE.io de fato
> envia). O esquema correto é `X-Hub-Signature` + HMAC-**SHA1** sobre os **bytes
> crus** do corpo, em hex.

A verificação é **estática** (não precisa de `Nfe::Client`, não lê configuração,
não faz rede):

```ruby
raw = request.body.read   # BYTES CRUS — leia ANTES de parsear o JSON
sig = request.get_header("HTTP_X_HUB_SIGNATURE")  # ou request.headers["X-Hub-Signature"]

if Nfe::Webhook.verify_signature(payload: raw, signature: sig, secret: ENV["NFE_WEBHOOK_SECRET"])
  event = Nfe::Webhook.construct_event(payload: raw, signature: sig, secret: ENV["NFE_WEBHOOK_SECRET"])
  # event.type, event.data, event.id, event.created_at
end
```

Pontos críticos:

- **Bytes crus.** A NFE.io assina exatamente os bytes que entregou. Leia
  `request.body.read` (ou `request.raw_post`) **antes** de parsear. **Nunca**
  re-serialize um objeto parseado (`payload.to_json`) — ordem de chaves e espaços
  diferem dos bytes assinados e a verificação falha de forma imprevisível.
- **HMAC-SHA1, hex, prefixo `sha1=`.** Comparação **case-insensitive** e
  **timing-safe** (`OpenSSL.secure_compare`). Um header `sha256=` é rejeitado.
- **`verify_signature` NUNCA levanta exceção:** retorna `false` para qualquer
  entrada ausente, malformada, algoritmo errado ou não-hex.
- **`construct_event` levanta `Nfe::SignatureVerificationError`** quando a
  assinatura não confere ou o payload não é JSON válido.
- **Validade ≠ frescor.** A NFE.io não envia timestamp/nonce anti-replay. Uma
  assinatura válida prova autenticidade, **não** frescor — seus handlers
  **precisam ser idempotentes** e deduplicar por `event.id` (ou pelo id da nota).

Há ainda o atalho `client.webhooks.verify_signature(payload:, signature:,
secret:)`, mera delegação a `Nfe::Webhook` (a API canônica é o módulo).

---

## 11. Downloads

Na `0.x`, `download(id, :pdf)` retornava o objeto de resposta do `rest-client`
(você acessava `.body`). Na `1.0`, os métodos de download retornam a **`String`
binária** diretamente (encoding `ASCII-8BIT`), pronta para `File.binwrite` ou
`send_data`.

```ruby
# 0.x
bytes = Nfe::ServiceInvoice.download("59443a...", :pdf).body

# 1.0 — String binária (bytes), sem .body
bytes = client.service_invoices.download_pdf(company_id: "55df...", invoice_id: "59443a...")
File.binwrite("nota.pdf", bytes)
```

Retornam `String` binária (`ASCII-8BIT`): `service_invoices`,
`consumer_invoices`, `transportation_invoices`, `inbound_product_invoices`,
`product_invoice_query`, `consumer_invoice_query` (e
`service_invoices_rtc.download_cancellation_xml`).

> ⚠️ **Exceção — `product_invoices` e `product_invoices_rtc`.** Seus
> `download_*` **não** retornam bytes: retornam um `Nfe::NfeFileResource` (value
> object com `uri`, `name`, `content_type`, `size`). O host `api.nfse.io/v2`
> responde com um envelope JSON `{ uri }` apontando para o arquivo — baixe os
> bytes a partir de `resource.uri` por conta própria.

```ruby
file = client.product_invoices.download_pdf(company_id:, invoice_id:)
file.uri   # => "https://.../danfe.pdf"  (não são bytes)
```

---

## 12. Recursos diferidos na `1.0`

Funcionalidades que existiam (ou se esperariam) e foram **deliberadamente
adiadas** na `1.0`, com o respectivo contorno:

| Diferido | Contorno na `1.0` |
|---|---|
| `create_and_wait` (emitir e aguardar) | emitir + loop de polling com `Nfe::FlowStatus.terminal?` (ver §9) |
| `create_batch` para notas | iterar `create` na sua aplicação (há `create_batch` apenas em `legal_people`/`natural_people`, e sequencial) |
| `getStatus` como chamada dedicada | derivado de `retrieve`: `client.service_invoices.get_status(...)` (sem HTTP extra) ou `Nfe::FlowStatus.terminal?(invoice.flow_status)` |
| upload/replace de certificado via multipart "rico" | `upload_certificate` / `replace_certificate` já existem (multipart simples + validação local fail-fast); não há ainda fluxo multipart estendido |
| `validate` de certificado server-side | `validate_certificate(file:, password:)` valida **localmente** (sem HTTP) |

---

## Apêndice A — Exemplo vanilla, lado a lado (emissão de NFS-e + polling)

### `0.x`

```ruby
require "nfe-io"

Nfe.api_key("c73d49f9649046eeba36dcf69f6334fd")
Nfe::ServiceInvoice.company_id("55df4dc6b6cd9007e4f13ee8")

invoice = Nfe::ServiceInvoice.create(
  borrower: { name: "Cliente Exemplo", federalTaxNumber: 12_345_678_000_199 },
  cityServiceCode: "2690",
  description: "Serviço de consultoria",
  servicesAmount: 100.0
)

# sem distinção de 202; sem contrato de polling padronizado
pdf = Nfe::ServiceInvoice.download(invoice["id"], :pdf).body
File.open("nota.pdf", "wb") { |f| f.write(pdf) }
```

### `1.0`

```ruby
require "nfe-io"

client = Nfe::Client.new(api_key: "c73d49f9649046eeba36dcf69f6334fd")
company_id = "55df4dc6b6cd9007e4f13ee8"

result = client.service_invoices.create(
  company_id: company_id,
  data: {
    borrower: { name: "Cliente Exemplo", federalTaxNumber: "12345678000199" },
    cityServiceCode: "2690",
    description: "Serviço de consultoria",
    servicesAmount: 100.0
  }
)

invoice =
  if result.pending?
    loop do
      current = client.service_invoices.retrieve(
        company_id: company_id, invoice_id: result.invoice_id
      )
      break current if Nfe::FlowStatus.terminal?(current.flow_status)
      sleep 2
    end
  else
    result.resource
  end

unless invoice.flow_status == "Issued"
  raise "emissão falhou: #{invoice.flow_status}"
end

bytes = client.service_invoices.download_pdf(
  company_id: company_id, invoice_id: invoice.id
)
File.binwrite("nota.pdf", bytes)
```

---

## Apêndice B — Exemplo Rails

### Initializer (`config/initializers/nfe.rb`) — `Nfe::Client` memoizado

Um único `Nfe::Client` é **seguro para compartilhar entre threads** (cada
acessor de recurso e cada transport é memoizado sob `Mutex`). Memoize-o:

```ruby
# config/initializers/nfe.rb
require "nfe-io"

module NfeClient
  def self.instance
    @instance ||= Nfe::Client.new(
      api_key: Rails.application.credentials.dig(:nfe, :api_key),
      data_api_key: Rails.application.credentials.dig(:nfe, :data_api_key),
      environment: Rails.env.production? ? :production : :development,
      logger: Rails.logger
    )
  end
end
```

### Controller de webhook — validando sobre `request.raw_post`

```ruby
# app/controllers/nfe_webhooks_controller.rb
class NfeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    raw    = request.raw_post                       # BYTES CRUS — não parsear antes
    sig    = request.headers["X-Hub-Signature"]
    secret = Rails.application.credentials.dig(:nfe, :webhook_secret)

    event = Nfe::Webhook.construct_event(payload: raw, signature: sig, secret: secret)

    # idempotência: a NFE.io não envia anti-replay — deduplique por event.id
    return head(:ok) if WebhookReceipt.exists?(event_id: event.id)
    WebhookReceipt.create!(event_id: event.id, event_type: event.type)

    ProcessNfeEventJob.perform_later(event.type, event.data)
    head :ok
  rescue Nfe::SignatureVerificationError
    head :bad_request
  end
end
```

---

## Resumo de breaking changes

**Entrada e configuração**

- Removido o estado global: `Nfe.api_key`, `Nfe.configure`, `Nfe.configuration`,
  `Nfe.access_keys`. Use `Nfe::Client.new(api_key:)`.
- Removido o estado mutável por classe (`Nfe::ServiceInvoice.company_id(...)`).
  `company_id:` agora é argumento de cada chamada.
- Removida a URL global única; o host é roteado por recurso (multi-host).
- Novo `data_api_key:` (com fallback para `api_key`) para famílias de dados.
- `environment:` é um **símbolo** que seleciona a **chave**, não a URL.

**Dependências e runtime**

- Removida a dependência `rest-client` (e a gem `json`). Zero deps de runtime.
- Ruby mínimo passa de 2.x para **3.2**.

**Modelos e API**

- `NfeObject` dinâmico → value objects imutáveis (`Data.define`), atributos
  `snake_case`.
- `Nfe::ServiceInvoice`/`Nfe::Company` deixam de ser classes ativas e viram
  value objects de leitura; o comportamento mora nos acessores do `Client`.
- `companies` usa `#remove` (não `#delete`).
- `create` de notas retorna um resultado discriminado `*Pending`/`*Issued`
  (antes retornava o objeto direto).
- `list` de `product_invoices`/`product_invoices_rtc` exige `environment:`
  (String `"Production"`/`"Test"`).

**Erros**

- `Nfe::NfeError` único → hierarquia tipada sob `Nfe::Error`.
- Exceções do `rest-client` → `Nfe::ApiConnectionError`/`Nfe::TimeoutError`.

**Webhooks**

- Esquema corrigido para `X-Hub-Signature` + HMAC-SHA1 sobre bytes crus
  (documentação antiga com `X-NFe-Signature`/SHA-256/Base64 estava errada).
- Handlers precisam ser idempotentes (sem anti-replay no provedor).

**Downloads**

- Retorno passa a ser `String` binária (`ASCII-8BIT`), sem `.body`.
- Exceção: `product_invoices`/`product_invoices_rtc` retornam
  `Nfe::NfeFileResource` (`uri`), não bytes.

**Recursos diferidos**

- Sem `create_and_wait`/`create_batch` para notas; faça polling com
  `Nfe::FlowStatus.terminal?`.
</content>
</invoke>
