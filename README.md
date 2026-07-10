# nfe-io — SDK Ruby oficial da NFE.io

> Emissão e gestão de documentos fiscais eletrônicos brasileiros (NFS-e, NF-e,
> NFC-e, CT-e) em Ruby, com ergonomia estilo Stripe e **zero dependências de runtime**.

[![Versão da gem](https://img.shields.io/gem/v/nfe-io.svg)](https://rubygems.org/gems/nfe-io)
[![CI](https://github.com/nfe/client-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/nfe/client-ruby/actions/workflows/ci.yml)
[![Cobertura](https://img.shields.io/badge/cobertura-%E2%89%A580%25-brightgreen.svg)](https://github.com/nfe/client-ruby/actions/workflows/ci.yml)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](LICENSE.txt)

> ⚠️ **v1 é uma reescrita greenfield.** A `v1.0.0` quebra **totalmente** a
> compatibilidade com a série `0.x`. A versão legada (`0.3.2`, baseada em
> `rest-client`) está **congelada** no branch [`0.x-legacy`](https://github.com/nfe/client-ruby/tree/0.x-legacy)
> e não recebe manutenção nem backports. Para fixá-la: `gem "nfe-io", "~> 0.3"`.
> Veja o [guia de migração](MIGRATION.md).

SDK oficial da [NFE.io](https://nfe.io) para Ruby.

- **Ergonomia estilo Stripe** — um único `Nfe::Client` com acessores de recurso `snake_case`.
- **Zero dependências de runtime** — apenas a stdlib do Ruby.
- **Tipado** — assinaturas RBS empacotadas em `sig/`, type-check com Steep.
- **Modelos imutáveis** (`Data.define`) gerados a partir das specs OpenAPI da documentação oficial.

## Requisitos

- **Ruby 3.2+** (CI em 3.2, 3.3 e 3.4).
- **Zero dependências de runtime.** O SDK usa apenas a biblioteca padrão do Ruby:
  `net/http`, `json`, `openssl`, `uri`, `securerandom`, `stringio`, `time`,
  `zlib`, `cgi`, `date` e `base64`.

## Instalação

Via Bundler (recomendado):

```ruby
# Gemfile
gem "nfe-io", "~> 1.0"
```

```sh
bundle install
# ou, sem editar o Gemfile manualmente:
bundle add nfe-io
```

Ou instalação direta:

```sh
gem install nfe-io
```

## Skill para agentes de IA

Além do gem, este repositório publica uma **skill de agente** (`nfeio-ruby-sdk`) que
ensina assistentes de IA (Claude Code, Cursor, Copilot, etc.) a usar o SDK corretamente.
São **dois canais distintos**:

| Canal | Comando | O quê |
|---|---|---|
| Código (RubyGems) | `gem install nfe-io` | O SDK Ruby |
| Skill de agente ([skills.sh](https://www.skills.sh/)) | `npx skills add https://github.com/nfe/client-ruby --skill nfeio-ruby-sdk` | O guia de uso para agentes |

O atalho `npx skills add nfe/client-ruby` também funciona. A skill é lida da árvore do
GitHub (slug `nfe/client-ruby`); ela **não** vem no `gem install` — o gemspec empacota
apenas `lib/`, `sig/` e os docs.

## Quickstart

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV["NFE_API_KEY"])

# Emite uma NFS-e (retorno discriminado por tipo — ver "Emissão assíncrona").
result = client.service_invoices.create(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  data: {
    cityServiceCode: "2690",
    description: "Manutenção e suporte técnico",
    servicesAmount: 100.0,
    borrower: { federalTaxNumber: "191", name: "Banco do Brasil SA" }
  }
)

# Quando enfileirada (HTTP 202), use o invoice_id para reconsultar.
invoice = client.service_invoices.retrieve(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  invoice_id: result.pending? ? result.invoice_id : result.resource.id
)
puts invoice.flow_status
```

## Configuração

`Nfe::Client.new` aceita os seguintes argumentos nomeados:

| Argumento | Default | Descrição |
|---|---|---|
| `api_key:` | _(ENV)_ | Chave principal. Fallback: `ENV["NFE_API_KEY"]`. |
| `data_api_key:` | `nil` | Chave das famílias de **dados**. Fallback: `ENV["NFE_DATA_API_KEY"]`, depois `api_key`. |
| `environment:` | `:production` | **Símbolo** `:production` \| `:development`. **Reservado para uso futuro** — hoje não altera endpoints/chaves (ver "Sandbox vs. Produção"). |
| `timeout:` | `30` | Timeout de leitura (segundos). |
| `max_retries:` | `3` | Orçamento de retentativas (inteiro ≥ 0). |
| `logger:` | `nil` | Logger opcional. |
| `user_agent_suffix:` | `nil` | Sufixo anexado ao `User-Agent` do SDK. |
| `configuration:` | `nil` | Um `Nfe::Configuration` já montado (veja "Opções avançadas"). Quando fornecido, os argumentos acima são ignorados. |

### Opções avançadas (`Nfe::Configuration`)

`open_timeout:` (timeout de conexão), `base_url_overrides:` (override de host por
família), `ca_file:`/`ca_path:` (CA bundle adicional — apenas **adiciona** confiança
TLS, nunca desabilita a verificação do peer) e `proxy:` (`String`/`URI` repassada
ao `Net::HTTP`) são definidos em um `Nfe::Configuration` e injetados via
`configuration:`:

```ruby
config = Nfe::Configuration.new(
  api_key: ENV["NFE_API_KEY"],
  open_timeout: 5,
  ca_file: "/etc/ssl/custom-ca.pem",
  proxy: ENV["HTTPS_PROXY"]
)
client = Nfe::Client.new(configuration: config)
```

```ruby
client = Nfe::Client.new(
  api_key: ENV["NFE_API_KEY"],
  data_api_key: ENV["NFE_DATA_API_KEY"],
  timeout: 60,
  user_agent_suffix: "minha-app/2.1"
)
```

### Precedência das chaves (ENV fallback)

1. **Argumento explícito** não vazio (`api_key:` / `data_api_key:`) sempre vence.
2. Caso contrário, a variável de ambiente correspondente (`NFE_API_KEY` /
   `NFE_DATA_API_KEY`), quando presente.
3. As famílias de **dados** caem da `data_api_key` para a `api_key` quando a
   primeira não foi resolvida.

Se nenhuma chave resolver, `Nfe::Client.new` levanta `Nfe::ConfigurationError`
(antes de qualquer requisição).

## Sandbox vs. Produção

> **Importante:** a separação **produção vs. teste (homologação)** é definida na
> configuração da sua conta em [app.nfe.io](https://app.nfe.io) (lado servidor) —
> **não** pela chave de API nem pelo SDK — e **não existe URL de sandbox**.
> O argumento `environment:` do `Nfe::Client` (`:production` / `:development`)
> está **reservado para uso futuro**: hoje ele é validado mas **não** altera
> endpoints, chaves ou comportamento.

Há um segundo conceito de "ambiente", **distinto e independente** do anterior:
NF-e/NFC-e (`product_invoices`, `consumer_invoices`, `product_invoices_rtc`)
aceitam um parâmetro `environment:` do tipo **String** (`"Production"` ou
`"Test"`) na **listagem** e na **emissão**, para escolher se o documento é
homologação ou produção na SEFAZ.

```ruby
# String "Production"/"Test" — NÃO confundir com o :production/:development do Client.
client.product_invoices.list(company_id: "co_1", environment: "Test", limit: 50)

# Emissão de teste (homologação SEFAZ):
client.product_invoices.create(
  company_id: "co_1",
  data: {
    environment: "Test",
    serie: 1,
    number: 1,
    # ... demais campos da NF-e
  }
)
```

## Mapa de recursos

A `v1` expõe **17 recursos canônicos** no `Nfe::Client` (mais 2 addons RTC).

| Acessor | Host | Escopo | Operações principais |
|---|---|---|---|
| `service_invoices` | `api.nfe.io` (`/v1`) | NFS-e | `create`, `retrieve`, `list`, `cancel`, `send_email`, `get_status`, `download_pdf`/`download_xml` |
| `companies` | `api.nfe.io` (`/v1`) | Empresas + certificado | `create`, `retrieve`, `list`, `update`, `remove`, `upload_certificate`, `get_certificate_status` |
| `legal_people` | `api.nfe.io` (`/v1`) | Pessoas jurídicas (tomadores) | `create`, `retrieve`, `list`, `update`, `delete`, `create_batch`, `find_by_tax_number` |
| `natural_people` | `api.nfe.io` (`/v1`) | Pessoas físicas (tomadores) | `create`, `retrieve`, `list`, `update`, `delete`, `create_batch`, `find_by_tax_number` |
| `webhooks` | `api.nfe.io` (`/v2`, conta) | Webhooks da conta | `create_account_webhook`, `retrieve_account_webhook`, `list_account_webhooks`, `update_account_webhook`, `delete_account_webhook`, `ping_account_webhook`, `fetch_event_types`, `verify_signature` |
| `product_invoices` | `api.nfse.io` (`/v2`) | NF-e | `create`, `create_with_state_tax`, `list`, `retrieve`, `cancel`, `send_correction_letter`, `disable`, `download_*` |
| `consumer_invoices` | `api.nfse.io` (`/v2`) | NFC-e | `create`, `create_with_state_tax`, `list`, `retrieve`, `cancel`, `disable_range`, `download_pdf`/`download_xml` |
| `transportation_invoices` | `api.nfse.io` (`/v2`) | CT-e (recepção) | `enable`, `disable`, `get_settings`, `retrieve`, `download_xml`, `get_event` |
| `inbound_product_invoices` | `api.nfse.io` (`/v2`) | NF-e de entrada / manifestação | `enable_auto_fetch`, `get_details`, `get_xml`, `get_pdf`, `manifest` |
| `tax_calculation` | `api.nfse.io` (`/v2`) | Motor de impostos | `calculate` |
| `tax_codes` | `api.nfse.io` (`/v2`) | Tabelas fiscais | `list_operation_codes`, `list_acquisition_purposes`, `list_issuer_tax_profiles` |
| `state_taxes` | `api.nfse.io` (`/v2`) | Inscrições estaduais (CRUD) | `create`, `retrieve`, `list`, `update`, `delete` |
| `product_invoice_query` | `nfe.api.nfe.io` | Consulta NF-e por chave | `retrieve`, `download_pdf`, `download_xml`, `list_events` |
| `consumer_invoice_query` | `nfe.api.nfe.io` | Consulta NFC-e por chave | `retrieve`, `download_xml` |
| `addresses` | `address.api.nfe.io` (`/v2`) | CEP / endereços | `lookup_by_postal_code`, `search`, `lookup_by_term` |
| `legal_entity_lookup` | `legalentity.api.nfe.io` | Consulta CNPJ | `get_basic_info`, `get_state_tax_info`, `get_state_tax_for_invoice` |
| `natural_person_lookup` | `naturalperson.api.nfe.io` | Consulta CPF | `get_status` |

> **Addons RTC (opt-in):** `service_invoices_rtc` e `product_invoices_rtc`
> emitem no leiaute da **Reforma Tributária (IBS/CBS)** — mesmos endpoints e
> mesmo fluxo discriminado/polling dos clássicos. São selecionados pela presença
> do grupo `ibsCbs` (NFS-e) ou `items[].tax.IBSCBS` (produto) no payload, sem
> header/parâmetro discriminador.

> **Roteamento multi-host** (automático, por recurso): cada família resolve seu
> próprio host — entidades e NFS-e em `api.nfe.io`; NF-e/NFC-e/CT-e e impostos em
> `api.nfse.io`; e os dados em hosts dedicados (`address.api.nfe.io`,
> `legalentity.api.nfe.io`, `naturalperson.api.nfe.io`, `nfe.api.nfe.io`). As
> quatro famílias de **dados dedicadas** (`addresses`, `legal_entity_lookup`,
> `natural_person_lookup`, `*_query`) usam a `data_api_key` (com fallback para
> `api_key`).

> **Não confundir:** `consumer_invoice_query` **consulta** um cupom NFC-e já
> emitido por chave de acesso (host `nfe.api.nfe.io`); `consumer_invoices`
> **emite** NFC-e (host `api.nfse.io`). Hosts e versões distintos.

## Recursos

Um exemplo curto por recurso:

```ruby
# NFS-e — emissão e download
client.service_invoices.create(company_id: "co_1", data: { ... })       # => Pending | Issued
bytes = client.service_invoices.download_pdf(company_id: "co_1", invoice_id: "in_1")

# NF-e — emissão (environment String obrigatório no list)
client.product_invoices.create(company_id: "co_1", data: { ... })       # => Pending | Issued
client.product_invoices.list(company_id: "co_1", environment: "Production")

# NFC-e
client.consumer_invoices.create(company_id: "co_1", data: { ... })
client.consumer_invoices.download_xml(company_id: "co_1", invoice_id: "in_1")

# CT-e (recepção) e NF-e de entrada
client.transportation_invoices.enable(company_id: "co_1")
client.inbound_product_invoices.manifest(company_id: "co_1", access_key: "352...")

# Empresas + certificado digital
company = client.companies.create(name: "Acme", federalTaxNumber: "12345678000199")
client.companies.upload_certificate(company.id, file: "cert.pfx", password: "senha")
client.companies.remove(company.id)        # delete chama-se "remove"

# Tomadores
client.legal_people.create("co_1", { federalTaxNumber: "12345678000199", name: "Cliente SA" })
client.natural_people.find_by_tax_number("co_1", "39053344705")

# Impostos
client.tax_calculation.calculate("tenant_1", { operationType: "...", items: [...] })
client.tax_codes.list_operation_codes
client.state_taxes.list("co_1")

# Consulta por chave de acesso (44 dígitos)
client.product_invoice_query.retrieve("3525...")     # NF-e
client.consumer_invoice_query.retrieve("3525...")    # NFC-e

# Dados
client.addresses.lookup_by_postal_code("01310100")
client.legal_entity_lookup.get_basic_info("12345678000199")
client.natural_person_lookup.get_status("39053344705", "1990-01-31")

# Emissão RTC (Reforma Tributária / IBS-CBS)
client.product_invoices_rtc.create(
  company_id: "co_1",
  data: {
    items: [{
      description: "Produto",
      tax: { IBSCBS: { situationCode: "000", classCode: "000001" } }
    }],
    payment: { ... }
  }
)
```

## Emissão assíncrona (HTTP 202)

A emissão geralmente é **assíncrona**. `create` devolve um **resultado
discriminado**:

- `*Pending` (HTTP 202, enfileirado) — expõe `invoice_id` e `location`;
  `pending?` ⇒ `true`, `issued?` ⇒ `false`.
- `*Issued` (HTTP 201, já materializado) — expõe `resource`; `issued?` ⇒ `true`.

Não há `create_and_wait` nem `create_batch` na v1.0 — faça **polling** chamando
`retrieve` até um estado terminal, usando `Nfe::FlowStatus.terminal?`. Os estados
terminais são: `Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`.

```ruby
result = client.service_invoices.create(company_id: "co_1", data: { ... })

case result
in Nfe::Resources::ServiceInvoicePending => pending
  invoice = nil
  loop do
    invoice = client.service_invoices.retrieve(
      company_id: "co_1", invoice_id: pending.invoice_id
    )
    break if Nfe::FlowStatus.terminal?(invoice.flow_status)

    sleep 2
  end
  invoice
in Nfe::Resources::ServiceInvoiceIssued => issued
  issued.resource # NFS-e já materializada (HTTP 201)
end
```

> **Atalho:** `service_invoices.get_status(company_id:, invoice_id:)` devolve um
> snapshot (`#complete?` / `#failed?` / `#invoice`) derivado de um único
> `retrieve` — útil dentro do loop de polling.

Os addons RTC seguem exatamente o mesmo contrato (`ProductInvoiceRtcPending` |
`ProductInvoiceRtcIssued`, polling com `product_invoices_rtc.retrieve`).

## Tratamento de erros

Toda exceção do SDK deriva de `Nfe::Error`, então `rescue Nfe::Error` captura a
família inteira. Erros vindos de uma resposta HTTP carregam contexto de
diagnóstico (`#status_code`, `#request_id`, `#error_code`); `#to_h` devolve uma
representação **segura para log** (sem corpo nem headers crus, que podem conter
segredos/PII).

```ruby
begin
  client.service_invoices.create(company_id: "co_1", data: { ... })
rescue Nfe::RateLimitError => e
  sleep(e.retry_after || 5)
  retry
rescue Nfe::InvalidRequestError => e
  warn "Payload inválido: #{e.message} (#{e.error_code})"
rescue Nfe::Error => e
  warn e.to_h.inspect
end
```

| Erro | HTTP / origem | Quando ocorre |
|---|---|---|
| `Nfe::AuthenticationError` | 401 | Chave ausente ou inválida. |
| `Nfe::AuthorizationError` | 403 | Chave válida, sem permissão para o recurso. |
| `Nfe::InvalidRequestError` | 400 / 422 | Requisição malformada ou reprovada na validação. |
| `Nfe::NotFoundError` | 404 | Recurso inexistente. |
| `Nfe::ConflictError` | 409 | Conflito com o estado atual do recurso. |
| `Nfe::RateLimitError` | 429 | Excesso de requisições. Expõe `#retry_after`. |
| `Nfe::ServerError` | 5xx | Falha no servidor da API. |
| `Nfe::ApiConnectionError` | rede | Falha de conexão (DNS, recusa, TLS, reset). |
| `Nfe::TimeoutError` | rede | Timeout (subclasse de `ApiConnectionError`). |
| `Nfe::SignatureVerificationError` | webhook | Assinatura de webhook inválida (em `construct_event`). |
| `Nfe::ConfigurationError` | local | Configuração inválida (chave faltando, `environment` inválido). |
| `Nfe::InvoiceProcessingError` | protocolo 202 | Resposta 202 sem `Location` utilizável. |

## Downloads

A maioria dos downloads devolve a **String binária** (`ASCII-8BIT`) com os bytes
do documento, pronta para `File.binwrite` ou `send_data`:

```ruby
bytes = client.service_invoices.download_pdf(company_id: "co_1", invoice_id: "in_1")
File.binwrite("nota.pdf", bytes)
```

Devolvem bytes: `service_invoices`, `consumer_invoices`,
`transportation_invoices`, `inbound_product_invoices` e os recursos de consulta
`product_invoice_query` / `consumer_invoice_query`.

> **Exceção:** `product_invoices.download_*` e `product_invoices_rtc.download_*`
> devolvem um **`Nfe::NfeFileResource`** (um value object com a `uri` do arquivo),
> **não** os bytes:
>
> ```ruby
> file = client.product_invoices.download_pdf(company_id: "co_1", invoice_id: "in_1")
> file.uri # => "https://.../danfe.pdf"
> ```

## Webhooks

Crie o webhook (escopo da **conta**, `/v2/webhooks`) e **verifique a
assinatura** de cada entrega. A NFE.io pinga a `uri` na criação e exige 2xx;
descubra os filtros válidos com `fetch_event_types`.

```ruby
client.webhooks.create_account_webhook(
  uri: "https://minha-app.com/webhooks/nfe",
  contentType: "json",
  secret: ENV["NFE_WEBHOOK_SECRET"],   # 32–64 caracteres
  filters: ["service_invoice.issued_successfully", "service_invoice.issued_error"],
  status: "Active"
)
```

> ⚠️ `update_account_webhook` faz **PUT integral**: campos omitidos voltam ao
> padrão — um update sem `status` desativa o webhook. Parta do
> `retrieve_account_webhook` e envie o objeto completo. Os métodos
> company-scoped (`create`/`list`/... com `company_id`) estão **deprecated** —
> a rota `/v1/companies/{id}/webhooks` retorna 404 na API atual.

A verificação é **HMAC-SHA1 sobre os bytes crus** da requisição (header
`X-Hub-Signature`, comparação case-insensitive e timing-safe). Leia o corpo bruto
**antes** de fazer parse do JSON — reserializar (`payload.to_json`) muda
ordem/whitespace e quebra a verificação.

```ruby
# Exemplo Rack/Rails
raw = request.body.read
sig = request.get_header("HTTP_X_HUB_SIGNATURE")

if Nfe::Webhook.verify_signature(payload: raw, signature: sig, secret: ENV["NFE_WEBHOOK_SECRET"])
  event = Nfe::Webhook.construct_event(payload: raw, signature: sig, secret: ENV["NFE_WEBHOOK_SECRET"])
  # processe event.type / event.data
end
```

- `Nfe::Webhook.verify_signature(...)` ⇒ `Boolean`. **Nunca levanta exceção** —
  qualquer entrada ausente/malformada/algoritmo errado retorna `false`.
- `Nfe::Webhook.construct_event(...)` ⇒ `Nfe::WebhookEvent` (levanta
  `Nfe::SignatureVerificationError` se a assinatura ou o JSON forem inválidos).

> **Validade ≠ atualidade.** A NFE.io **não** envia timestamp/nonce
> anti-replay. Uma assinatura válida prova autenticidade, **não** frescor. Seus
> handlers **devem ser idempotentes** e deduplicar pelo id do evento/da nota.

## Versionamento

O projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

- **patch** (`1.0.x`): correções, liberadas direto após CI verde.
- **minor**/**major**: novas capacidades / quebras de contrato, precedidas de
  ciclo de **release candidate** (`-rc.N`) e **beta** (`-beta.N`).

Consulte o [`CHANGELOG.md`](CHANGELOG.md) para o histórico e o
[`MIGRATION.md`](MIGRATION.md) para o guia de migração da `0.x`.

## Type checking

A gem **empacota** as assinaturas RBS em `sig/`. Quem consome o SDK pode
type-checkar o próprio código contra elas com [Steep](https://github.com/soutaro/steep):

```ruby
# Gemfile
gem "steep", require: false
```

```ruby
# Steepfile
target :app do
  signature "sig"
  check "lib"

  library "nfe-io" # usa as assinaturas empacotadas com a gem
end
```

```sh
bundle exec steep check
```

## Migração da `0.x`

Veja [`MIGRATION.md`](MIGRATION.md). Em resumo: a API global (`Nfe.api_key(...)`,
`Nfe::ServiceInvoice.create`) dá lugar a `Nfe::Client.new(api_key:)` +
`client.service_invoices.create`, sem `rest-client` e com value objects imutáveis.

## Contribuindo

Veja [`CONTRIBUTING.md`](CONTRIBUTING.md) para setup local, toolchain (`rake spec`,
`rubocop`, `steep check`, `rake generate`), convenções e fluxo de release.

## Licença

MIT. Veja [`LICENSE.txt`](LICENSE.txt).
