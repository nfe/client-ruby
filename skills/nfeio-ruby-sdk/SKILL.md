---
name: nfeio-ruby-sdk
description: >-
  Use ao escrever ou revisar Ruby que integra a NFE.io via o gem oficial "nfe-io"
  (require "nfe", Nfe::Client). Acione quando o código mencionar Nfe::Client,
  NFE.io, emissão/consulta de nota fiscal eletrônica (NFS-e / NF-e / NFC-e / CT-e),
  consulta de CNPJ / CPF / CEP (legal entity, natural person, address lookup),
  verificação de assinatura de webhook (X-Hub-Signature), carta de correção (CC-e),
  inutilização, certificado digital A1, ou cálculo de impostos. Cobre os 17
  recursos canônicos + 2 addons RTC (Reforma Tributária — IBS/CBS/IS). Ruby 3.2+,
  zero dependências de runtime (stdlib only).
---

# NFE.io Ruby SDK (gem `nfe-io`, v1.0)

SDK oficial da NFE.io para Ruby. Cliente estilo Stripe, **thread-safe**, **zero
dependências de runtime** (só stdlib: `net/http`, `json`, `openssl`, `uri`,
`securerandom`, `time`, `zlib`, `cgi`, `date`, `base64`). Ruby **3.2+**.

> Use os nomes EXATOS deste documento. A v1 NÃO é compatível com a 0.3.x (que
> tinha `Nfe.api_key` global e `Nfe::ServiceInvoice.company_id(...).create`).

## Gem & require

```ruby
# Gemfile
gem "nfe-io", "~> 1.0"
```

```ruby
require "nfe"   # carrega tudo sob o namespace Nfe::
```

O gem publica `sig/**/*.rbs` — consumidores podem rodar `steep check` contra os
tipos.

## Quickstart

```ruby
client = Nfe::Client.new(api_key: "sua-chave")        # produção, defaults sãos
client.service_invoices                                # acessor lazy + memoizado
```

Assinatura completa do construtor de `Nfe::Client.new` (kwargs):

```ruby
Nfe::Client.new(
  api_key: nil,             # fallback ENV NFE_API_KEY (argumento explícito vence)
  data_api_key: nil,        # fallback ENV NFE_DATA_API_KEY
  configuration: nil,       # quando passado, IGNORA os demais kwargs abaixo
  environment: :production, # SÍMBOLO :production | :development — reservado p/ uso futuro (sem efeito hoje)
  timeout: 30,              # read timeout (s)
  max_retries: 3,           # tentativas após a 1ª
  logger: nil,
  user_agent_suffix: nil
)
```

> **Atenção:** o construtor de `Client` NÃO aceita
> `open_timeout:`, `base_url_overrides:`, `ca_file:`, `ca_path:` nem `proxy:`
> diretamente. Esses campos vivem em `Nfe::Configuration`. Para usá-los, construa
> a configuração e injete via `configuration:`:

```ruby
config = Nfe::Configuration.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  open_timeout: 10,
  base_url_overrides: { main: "https://mock.local" }, # escape hatch p/ testes/proxy
  ca_file: "/etc/ssl/custom-ca.pem",   # SÓ adiciona CA; não há como desabilitar verificação TLS
  proxy: "http://proxy:3128"
)
client = Nfe::Client.new(configuration: config)
```

`environment:` (`:production`/`:development`) é um **símbolo reservado para uso
futuro**: hoje é validado mas não altera endpoints/chaves. A separação
produção/teste (homologação) é definida na conta em https://app.nfe.io.

## Sandbox vs Produção

- Não há host de sandbox separado. Produção/teste é definido na **conta**
  (https://app.nfe.io), **não** pela chave; o `environment:` Símbolo do `Client`
  está reservado para uso futuro.
- Para os recursos de **product/consumer invoices**, `list` exige um parâmetro
  `environment:` **String separado** (`"Production"` ou `"Test"`) — distinto do
  `environment:` Símbolo do `Client`. Eles coexistem e significam coisas diferentes.

```ruby
client.product_invoices.list(company_id: id, environment: "Test")   # String!
```

## Mapa de recursos

19 acessores snake_case = 17 canônicos + 2 addons RTC. Roteamento de host é
**automático** por recurso (você nunca monta URL).

| Acessor | Host | Escopo | Operações principais |
|---|---|---|---|
| `service_invoices` | api.nfe.io `/v1` | NFS-e (emissão) | create, list, retrieve, cancel, send_email, download_pdf/xml, get_status |
| `product_invoices` | api.nfse.io `/v2` | NF-e (mod 55) | create, create_with_state_tax, list*, retrieve, cancel, list_items/events, send_correction_letter, disable, disable_range, download_* |
| `consumer_invoices` | api.nfse.io `/v2` | NFC-e (emissão) | create, create_with_state_tax, list, retrieve, cancel, list_items/events, disable_range, download_pdf/xml/rejection_xml |
| `transportation_invoices` | api.nfse.io `/v2` | CT-e inbound | enable, disable, get_settings, retrieve, get_event, download_xml/event_xml |
| `inbound_product_invoices` | api.nfse.io `/v2` | NF-e recebida | enable_auto_fetch, disable_auto_fetch, get_settings, get_details, get_product_invoice_details, manifest, reprocess_webhook, get_xml/pdf/json |
| `product_invoice_query` | nfe.api.nfe.io | NF-e (consulta por chave) | retrieve, download_pdf, download_xml, list_events |
| `consumer_invoice_query` | nfe.api.nfe.io `/v1` | cupom NFC-e (consulta) | retrieve, download_xml |
| `companies` | api.nfe.io `/v1` | empresas + certificado A1 | create, list, retrieve, update, **remove**, find_by_*, upload_certificate, get_certificate_status |
| `legal_people` | api.nfe.io `/v1` | PJ (tomadores) | list, create, retrieve, update, delete, create_batch, find_by_tax_number |
| `natural_people` | api.nfe.io `/v1` | PF (tomadores) | list, create, retrieve, update, delete, create_batch, find_by_tax_number |
| `webhooks` | api.nfe.io `/v2` (conta) | webhooks da conta | create_account_webhook, list_account_webhooks, retrieve_account_webhook, update_account_webhook, delete_account_webhook, ping_account_webhook, fetch_event_types (company-scoped list/create/... deprecated: rota 404) |
| `addresses` | address.api.nfe.io `/v2` | consulta de CEP | lookup_by_postal_code, search, lookup_by_term |
| `legal_entity_lookup` | legalentity.api.nfe.io | consulta CNPJ | get_basic_info, get_state_tax_info, get_state_tax_for_invoice, get_suggested_state_tax_for_invoice |
| `natural_person_lookup` | naturalperson.api.nfe.io | consulta CPF | get_status(cpf, birth_date) |
| `tax_calculation` | api.nfse.io | motor de impostos | calculate(tenant_id, request) |
| `tax_codes` | api.nfse.io | tabelas CT-e | list_operation_codes, list_acquisition_purposes, list_issuer/recipient_tax_profiles |
| `state_taxes` | api.nfse.io `/v2` | Inscrição Estadual | list, create, retrieve, update, delete |
| `service_invoices_rtc` | api.nfe.io `/v1` | NFS-e RTC (IBS/CBS) | create, retrieve, cancel, download_cancellation_xml |
| `product_invoices_rtc` | api.nfse.io `/v2` | NF-e/NFC-e RTC (IBSCBS) | create, create_with_state_tax, list*, retrieve, cancel, list_items/events, send_correction_letter, disable, disable_range, download_* |

`*` = `list` exige `environment:` String. Famílias **DATA** (`addresses`,
`legal_entity`, `natural_person`, `nfe_query`) usam `data_api_key` (fallback
`api_key`). O host `api.nfse.io` (família `:cte`) usa `api_key` e **NÃO** é
família de dados — divergência deliberada do SDK Node.

> **Convenção de argumentos (mista, intencional):** recursos de emissão usam
> kwargs (`create(company_id:, data:)`); `companies`, `legal_people`,
> `natural_people`, `state_taxes`, `webhooks` e os lookups usam **posicionais**
> (`companies.create(data)`, `companies.retrieve(company_id)`,
> `legal_entity_lookup.get_basic_info(cnpj)`). Sempre confira a assinatura.

## Contrato 202 (Pending / Issued)

Emissão é tipicamente **assíncrona**. `create` retorna um resultado
**discriminado**:

- **`*Pending`** (HTTP 202): `#invoice_id`, `#location`; `pending? => true`, `issued? => false`.
- **`*Issued`** (HTTP 201/200): `#resource` (DTO hidratado); `issued? => true`, `pending? => false`.

Não existe `create_and_wait`/`create_batch` para notas em v1.0. Faça polling:

```ruby
result = client.service_invoices.create(company_id: id, data: payload)

case result
in Nfe::Resources::ServiceInvoicePending => p
  loop do
    inv = client.service_invoices.retrieve(company_id: id, invoice_id: p.invoice_id)
    break inv if Nfe::FlowStatus.terminal?(inv.flow_status)
    sleep 2
  end
in Nfe::Resources::ServiceInvoiceIssued => i
  i.resource
end
```

`Nfe::FlowStatus::TERMINAL = %w[Issued IssueFailed Cancelled CancelFailed]`.

> Atalho só em `service_invoices`: `get_status(company_id:, invoice_id:)` retorna
> um `StatusResult` com `#complete?` e `#failed?` (deriva de `retrieve`, sem HTTP
> extra). Veja `references/service-invoices-and-polling.md`.

## Tratamento de erros

Toda exceção deriva de `Nfe::Error` (rescue único pega tudo). Cada erro carrega
`#status_code`, `#request_id`, `#error_code`, `#response_body`, `#response_headers`
e um `#to_h` seguro para log (sem body/headers).

| Classe | HTTP | Notas |
|---|---|---|
| `Nfe::AuthenticationError` | 401 | chave ausente/inválida |
| `Nfe::AuthorizationError` | 403 | chave sem permissão |
| `Nfe::InvalidRequestError` | 400/422 | payload inválido (+ validações client-side) |
| `Nfe::NotFoundError` | 404 | recurso inexistente |
| `Nfe::ConflictError` | 409 | conflito de estado |
| `Nfe::RateLimitError` | 429 | tem `#retry_after` |
| `Nfe::ServerError` | 5xx | falha no servidor |
| `Nfe::ApiConnectionError` | — | falha de rede (DNS/conexão/TLS) |
| `Nfe::TimeoutError` | — | subclasse de `ApiConnectionError` |
| `Nfe::SignatureVerificationError` | — | assinatura de webhook inválida |
| `Nfe::ConfigurationError` | — | mal-configurado (antes de qualquer HTTP) |
| `Nfe::InvoiceProcessingError` | — | 202 sem `Location` utilizável |

> Nomes que **NÃO existem**: `ConnectionError`, `ValidationError`,
> `PollingTimeoutError`. Use os da tabela.

```ruby
begin
  client.service_invoices.create(company_id: id, data: payload)
rescue Nfe::RateLimitError => e
  sleep(e.retry_after || 5); retry
rescue Nfe::InvalidRequestError => e
  logger.warn(e.to_h)        # seguro para log
rescue Nfe::Error => e       # rede a partir das classes específicas
  raise
end
```

## Paginação

`Nfe::ListResponse` inclui `Enumerable` (delega `each` a `#data`) e expõe `#data`
+ `#page`. `Nfe::ListPage` traz `#page_index`/`#page_count` (page-style) OU
`#starting_after`/`#ending_before` (cursor-style), além de `#total`.

```ruby
client.service_invoices.list(company_id: id).each { |inv| ... }   # já é Enumerable
```

- **page-style**: `service_invoices.list`, `companies.list`, `tax_codes.*`.
- **cursor-style**: `product_invoices.list`, `consumer_invoices.list`, `state_taxes.list`.
- `product_invoices.list` e `product_invoices_rtc.list` **exigem** `environment:`
  String (`"Production"`/`"Test"`), senão levantam `InvalidRequestError`.

## Downloads

Por padrão, os `download_*` retornam **bytes binários** (`String` ASCII-8BIT) →
grave com `File.binwrite`:

```ruby
File.binwrite("nota.pdf", client.service_invoices.download_pdf(company_id: id, invoice_id: iid))
```

Retornam bytes: `service_invoices`, `consumer_invoices`, `transportation_invoices`,
`inbound_product_invoices`, `product_invoice_query`, `consumer_invoice_query`.

> **EXCEÇÃO:** `product_invoices` e `product_invoices_rtc` retornam um
> `Nfe::NfeFileResource` (objeto de valor `{ uri, name, content_type, size }`),
> **NÃO** bytes — o host responde com um envelope JSON `{ uri }`.

```ruby
file = client.product_invoices.download_pdf(company_id: id, invoice_id: iid)
file.uri   # baixe você mesmo a partir desta URI
```

## Webhooks

Verificação é estática, sem `Client` e sem rede:

```ruby
raw = request.body.read                              # bytes BRUTOS, antes do parse JSON
sig = request.get_header("HTTP_X_HUB_SIGNATURE")     # header X-Hub-Signature

if Nfe::Webhook.verify_signature(payload: raw, signature: sig, secret: ENV.fetch("NFE_WEBHOOK_SECRET"))
  event = Nfe::Webhook.construct_event(payload: raw, signature: sig, secret: ENV.fetch("NFE_WEBHOOK_SECRET"))
  # event => Nfe::WebhookEvent(type:, data:, id:, created_at:)
end
```

- **HMAC-SHA1** sobre os **bytes brutos** da request; header `X-Hub-Signature`
  (prefixo `sha1=`), comparação case-insensitive e **timing-safe**.
- `verify_signature` **nunca levanta** (retorna `false` em qualquer entrada
  inválida). `construct_event` levanta `SignatureVerificationError` se a
  assinatura/JSON falhar.
- Nunca re-serialize o objeto parseado (`payload.to_json`) — ordem de chaves
  difere dos bytes assinados.
- **Validade ≠ frescor:** a NFE.io não envia timestamp/nonce anti-replay. Uma
  assinatura válida prova autenticidade, não frescor → handlers DEVEM ser
  **idempotentes** e **deduplicar** por `event.id` / id da nota.
- Esquema legado `X-NFe-Signature` / SHA-256 / Base64 **não** é suportado (e está
  errado em docs antigas).

## Pitfalls idiomáticos

- `companies` apaga com `#remove(company_id)` (retorna `{ deleted:, id: }`), **não**
  `#delete`. Já `legal_people`/`natural_people`/`state_taxes` usam `#delete`; `webhooks`
  usa `#delete_account_webhook(id)` (e `#delete_all_account_webhooks` apaga TODOS — destrutivo).
- Webhooks são **account-scoped** (`/v2/webhooks`): o create pinga a `uri` e exige 2xx
  (endpoint no ar antes); `secret` 32–64 chars (ecoado só no create); o
  `update_account_webhook` é **PUT integral** — sem `status`, o hook é desativado
  (parta do retrieve). Filtros válidos via `fetch_event_types`
  (`service_invoice.*`/`product_invoice.*`/`consumer_invoice.*`; os literais
  `invoice.*` de `get_available_events` estão deprecated e não existem na API).
- Recursos de emissão usam **keyword args**; entidades/lookups usam **posicionais**
  (ver nota no Mapa de recursos).
- Objetos de valor são `Data.define` **imutáveis** (Pending/Issued, ServiceInvoice,
  NfeFileResource, WebhookEvent, ListResponse, ListPage…).
- **Chaves de acesso = 44 dígitos**; separadores são removidos automaticamente.
- **Carta de correção (CC-e)**: `reason` deve ter **15..1000 caracteres** (validado
  client-side antes do HTTP). CC-e existe só para NF-e/CT-e — NFC-e não tem.
- `idempotency_key:` nas emissões vira header `Idempotency-Key`. O SDK **não**
  re-tenta emissões automaticamente; reenviar com a MESMA chave após timeout deixa
  o servidor deduplicar.
- `request_options: Nfe::RequestOptions.new(api_key:, base_url:, timeout:)` faz
  override por chamada (multi-tenant) sem mutar o `Client`.

## Árvore de decisão ("Quero…")

- **Emitir NFS-e** → `service_invoices.create(company_id:, data:)` → polling.
- **Emitir NF-e** → `product_invoices.create(company_id:, data:)` (202 → webhook).
- **Emitir NFC-e** → `consumer_invoices.create(company_id:, data:)`.
- **Emitir nota com IBS/CBS/IS (Reforma)** → `service_invoices_rtc` /
  `product_invoices_rtc` → `references/rtc-emission.md`.
- **Cancelar / carta de correção / inutilizar** → métodos do recurso de emissão →
  `references/product-invoices-and-taxes.md`.
- **Consultar nota de terceiro por chave de 44 dígitos** → `product_invoice_query` /
  `consumer_invoice_query`, ou inbound (`transportation_invoices` /
  `inbound_product_invoices`).
- **Consultar CNPJ / CPF / CEP** → `legal_entity_lookup` / `natural_person_lookup` /
  `addresses` → `references/data-services-and-lookups.md`.
- **Calcular impostos** → `tax_calculation.calculate(tenant_id, request)`.
- **Verificar webhook** → `Nfe::Webhook.verify_signature(...)`.
- **Criar/gerenciar webhooks da conta** → `webhooks.create_account_webhook(...)`
  (envelope `webHook` automático; filtros via `fetch_event_types`) →
  `references/error-handling-and-patterns.md`.
- **Tratar erros / retry / multi-tenant** → `references/error-handling-and-patterns.md`.

## Referências

- `references/service-invoices-and-polling.md` — NFS-e ponta a ponta + polling/get_status.
- `references/product-invoices-and-taxes.md` — NF-e/NFC-e, CC-e, inutilização, state_taxes, tax_codes, tax_calculation.
- `references/data-services-and-lookups.md` — addresses, legal/natural lookup, query por chave, certificados, companies/people.
- `references/error-handling-and-patterns.md` — hierarquia de erros, retries, idempotência, request_options, webhooks.
- `references/rtc-emission.md` — emissão RTC (IBS/CBS/IS) de serviço e produto.
