# add-http-transport

## Why

A API da NFE.io vive em **múltiplos hosts** (`api.nfe.io`, `api.nfse.io`, `address.api.nfe.io/v2`, `nfe.api.nfe.io`, `legalentity.api.nfe.io`, `naturalperson.api.nfe.io`), responde **202 + `Location`** para emissões assíncronas, devolve **downloads binários** (PDF/XML/ZIP), e tem o comportamento de rede de qualquer SaaS sério: throttling (429 com `Retry-After`), 5xx transientes, e gzip. O SDK v0.3.2 (rest-client, congelado em `0.x-legacy`) embute tudo isso de forma frágil e acoplada.

A decisão canônica do rewrite v1 é **zero dependências de runtime — só stdlib** (`net/http`, `json`, `openssl`, `uri`, `securerandom`, `stringio`, `time`, `base64`). Isolar o HTTP numa camada testável é pré-requisito para todo recurso: o `Nfe::Client` (em `add-client-core`) injeta o transport, e os 17 recursos (em `add-invoice-resources` e changes irmãs) só conversam com a API pública dessa camada. Esta change entrega esse alicerce, espelhando as taxonomias de erro e o contrato 202 do SDK Node.js e PHP, mas em Ruby idiomático (`Data.define`, keyword args, `raise` de erros tipados, retorno síncrono em vez de `Promise`).

Depende de **add-ruby-foundation** (gem `nfe-io`, namespace `Nfe`, piso Ruby 3.2, `# frozen_string_literal: true` em todo `.rb`, RBS/Steep/RuboCop/RSpec, SimpleCov >= 80%). É consumida por **add-client-core** (que injeta o transport e resolve o host map) e por todas as changes de recurso.

## What Changes

### Transport e value objects

- **`Nfe::Http::Transport`** — interface duck-typed (módulo + `raise NotImplementedError`) com um único método `call(request) -> response`. Permite substituir o transport em testes sem tocar em rede.
- **`Nfe::Http::NetHttp`** — implementação default, zero-dep, sobre `Net::HTTP`. TLS com verificação obrigatória (`OpenSSL::SSL::VERIFY_PEER`), reuso de conexão persistente por host (`keep-alive`) com **pool guardado por `Mutex` (thread-safe sob Rails/Sidekiq/Puma)**, timeouts separados de `open` e `read`, `Accept-Encoding: gzip` com descompressão automática (descartando/recalculando `content-length` após inflar), e honra de overrides por chamada (`Nfe::RequestOptions`: `api_key`/`base_url`/`timeout`) sem mutar config global.
- **`Nfe::Http::Request`** — value object imutável (`Data.define`) com `method`, `base_url`, `path`, `headers`, `query`, `body`, `open_timeout`, `read_timeout`, `idempotency_key`. Helper `#url` compõe `base_url + path + query`.
- **`Nfe::Http::Response`** — value object imutável (`Data.define`) com `status`, `headers` (chaves lowercase), `body` (String binária). Helpers `#header(name)`, `#success?`, `#location`.

### Confiabilidade

- **`Nfe::Http::RetryPolicy`** — `Data.define` com `max_retries` (default 3), `base_delay` (1.0s), `max_delay` (30.0s), `jitter` (0.3 = ±30%); fábricas `.default` e `.none`; `#delay_for(attempt)` calcula backoff exponencial com jitter limitado.
- **`Nfe::Http::RetryingTransport`** — decorator que envolve qualquer `Transport`. Faz retry em **429**, **5xx** e **erros de rede** somente para requisições idempotentes; honra `Retry-After` (segundos inteiros); aplica backoff + jitter; aceita um `sleep` injetável para testes determinísticos.

### Autenticação, identidade e observabilidade

- **Header de auth**: `X-NFE-APIKEY: <api_key>` injetado pela camada (paridade exata com Node `buildHeaders`).
- **User-Agent**: `NFE.io Ruby Client v<version> ruby/<ruby-version> (<platform>)`, lido de `Nfe::VERSION` (de `add-ruby-foundation`).
- **Idempotency-Key**: suporte de **slot** — `Request` carrega o campo e o transport envia `Idempotency-Key` quando presente. A chave é **fornecida pelo chamador** via kwarg `idempotency_key:` nos métodos de emissão (`create`/`create_with_state_tax`), **nunca auto-gerada** pelo transport. POST **não** é auto-retried (default de segurança), divergindo deliberadamente de Node/PHP (que repetem POST) — divergência documentada para integradores no README (release-tooling); só vira retry-eligible quando o chamador passa a chave; não enviado por padrão.
- **Logger duck-typed (equivalente PSR-3)**: `Configuration#logger` aceita qualquer objeto que responda a `info`/`warn`/`error` (incluindo `::Logger` da stdlib). Quando presente, loga início de request (`info`), retry (`warn`) e falha (`error`), sempre com **redação** de `X-NFE-APIKEY`, `Authorization` e qualquer `secret` (substituídos por `[REDACTED]`). **Por padrão NÃO loga corpos** de request/response (só método, URL, status, `request_id`); log de corpo é opt-in explícito (`Configuration#log_request_body`), truncado e redigido — CNPJ/CPF e senha de certificado nunca vazam em log.

### Hierarquia de erros (`Nfe::*`)

- `Nfe::Error` (base) carregando `message`, `status_code`, `request_id`, `error_code`, `response_body`, `response_headers`; `#to_h` para logging.
- `Nfe::AuthenticationError` (401), `Nfe::AuthorizationError` (403), `Nfe::InvalidRequestError` (400/422), `Nfe::NotFoundError` (404), `Nfe::ConflictError` (409), `Nfe::RateLimitError` (429), `Nfe::ServerError` (5xx), `Nfe::ApiConnectionError` (rede), `Nfe::TimeoutError` (timeout), `Nfe::SignatureVerificationError` (definido aqui, consumido por webhooks).
- **`Nfe::ErrorFactory`** — mapeia `status` + corpo para o erro tipado, extraindo `message`/`error_code`/`request_id` do payload e dos headers (`x-request-id`).

### Fora de escopo (decisões registradas)

- **Não seguir 202/redirects automaticamente** — o transport devolve `Response` cru com `Location`; quem decide é o recurso (contrato Pending/Issued mora em `add-client-core`).
- **Polling (`pollUntilComplete`/`create_and_wait`)** — diferido; o contrato 202 nasce correto, mas o helper de polling é entregue depois.
- **`createBatch`/concorrência** — fora de escopo; Ruby síncrono não tem ganho real aqui.

## Capabilities

### New Capabilities
- `http-transport`: contrato de transport (`Net::HTTP`), value objects request/response, retry com backoff + jitter, multi-base-URL, hierarquia de erros tipados + `ErrorFactory`, User-Agent, auth header, idempotency-key slot, logger duck-typed com redação.

### Modified Capabilities
- (nenhuma) — esta é a primeira change a introduzir a capability `http-transport`.

## Impact

- **Affected code**: `lib/nfe/http/*` (transport, request, response, retry_policy, retrying_transport, user_agent), `lib/nfe/errors.rb` (+ `lib/nfe/error_factory.rb`), assinaturas em `sig/nfe/http/*.rbs` e `sig/nfe/errors.rbs`, testes em `spec/nfe/http/*` e `spec/nfe/error_factory_spec.rb`.
- **Spec impact**: adiciona a capability `http-transport`.
- **Dependencies**: depende de `add-ruby-foundation` (gem, namespace, `Nfe::VERSION`, toolchain). Consumida por `add-client-core` (injeção do transport + host map) e pelas changes de recurso.
- **Riscos**:
  - `Net::HTTP` separa parsing de header/body de forma diferente do cURL/fetch — testes cobrem normalização lowercase e gzip.
  - Reuso de conexão persistente entre hosts diferentes exige pool por `host:port` — mitigado mantendo um `Net::HTTP` por origem.
  - Retry só em métodos idempotentes evita reemissão indevida de invoice (POST não idempotente sem `Idempotency-Key`).
