# Tasks — add-http-transport

> Esta change depende de `add-ruby-foundation`
> (gem `nfe-io`, namespace `Nfe`, `Nfe::VERSION`, piso Ruby 3.2, `# frozen_string_literal: true`
> em todo `.rb`, RBS/Steep/RuboCop/RSpec, SimpleCov >= 80%). Consumida por `add-client-core`
> (injeção do transport + host map) e pelas changes de recurso.
>
> **Status (2026-06-24): IMPLEMENTADO e verificado verde via Docker na matrix Ruby 3.2/3.3/3.4.**
> Entregues §1–§9 e §11: value objects (`Request`/`Response`), `Transport` + `NetHttp` (pool com mutex, TLS VERIFY_PEER, gzip, timeouts), `RetryPolicy` + `RetryingTransport` (backoff/jitter, Retry-After, sem retry de POST não-idempotente), `UserAgent`, `Redactor`, hierarquia de erros `Nfe::Error` + `ErrorFactory`, logger duck-typed sem corpos, e specs (128 exemplos, cobertura de linha ~97.5%). Gate: `rspec` 128/0, `rubocop` 0 offenses, `steep` 0 erros, `rbs validate` ok — nos três Rubies. §12 (smoke manual em sandbox) permanece DEFERRED (precisa chave). Decisões de design realizadas durante a verificação: value objects usam `class X < Data.define(...)` (forma que o Steep resolve); `Request#method` mantém o nome (expõe o verbo HTTP); cops `Style/DataInheritance`/`Lint/DataDefineOverride` desabilitados com justificativa; `Layout/LeadingCommentSpace` aceita anotações RBS inline `#:`.

## 1. Value objects: Request e Response

- [ ] 1.1 Criar `lib/nfe/http/request.rb` — `Nfe::Http::Request = Data.define(:method, :base_url, :path, :headers, :query, :body, :open_timeout, :read_timeout, :idempotency_key)`. Defaults: `headers: {}`, `query: {}`, `body: nil`, `open_timeout: nil`, `read_timeout: nil`, `idempotency_key: nil`. `# frozen_string_literal: true` no topo.
- [ ] 1.2 Adicionar método `#url` em `Request` — compõe `base_url.chomp("/") + path`, anexa `?` + `URI.encode_www_form(query)` quando `query` não vazio; usa `&` se `path` já tiver `?`. Arrays em query viram chaves repetidas.
- [ ] 1.3 Adicionar `#idempotent?` em `Request` — true para `GET`/`HEAD`/`PUT`/`DELETE` (case-insensitive) OU quando `idempotency_key` presente.
- [ ] 1.4 Criar `lib/nfe/http/response.rb` — `Nfe::Http::Response = Data.define(:status, :headers, :body)`. Headers com **chaves lowercase**. `body` é String `ASCII-8BIT`.
- [ ] 1.5 Adicionar helpers em `Response`: `#header(name)` (lookup case-insensitive via `headers[name.downcase]`), `#success?` (`(200..299).cover?(status)`), `#location` (`header("location")`).

## 2. Transport: interface + default Net::HTTP

- [ ] 2.1 Criar `lib/nfe/http/transport.rb` — `module Nfe::Http::Transport` documentando o contrato: `def call(request) = raise NotImplementedError`. Documentar regras (não seguir 202/redirect; headers lowercase no Response; levantar só `ApiConnectionError`/`TimeoutError` em falha de rede; devolver 4xx/5xx como Response).
- [ ] 2.2 Criar `lib/nfe/http/net_http.rb` — `Nfe::Http::NetHttp` implementa `call(request)`. Constructor aceita `default_open_timeout: 10`, `default_read_timeout: 60`, `ca_file: nil`.
- [ ] 2.3 `NetHttp`: pool de conexões por origem — cache `Hash` keyed por `"#{host}:#{port}"` de instâncias `Net::HTTP` iniciadas (`start`), com `keep_alive_timeout` para reuso TCP/TLS.
- [ ] 2.4 `NetHttp`: TLS — `use_ssl = (uri.scheme == "https")`, `verify_mode = OpenSSL::SSL::VERIFY_PEER`, aplicar `ca_file` quando setado. Nunca desabilitar verificação por default.
- [ ] 2.5 `NetHttp`: timeouts — aplicar `open_timeout`/`read_timeout` do `Request` quando presentes, senão os defaults do transport.
- [ ] 2.6 `NetHttp`: construir o objeto `Net::HTTP::Get/Post/Put/Delete/Head` a partir de `request.method`; setar headers do request; setar `body` quando presente; setar `Accept-Encoding: gzip` se o caller não tiver setado.
- [ ] 2.7 `NetHttp`: executar a request; capturar `Timeout::Error`/`Net::OpenTimeout`/`Net::ReadTimeout` → `raise Nfe::TimeoutError`; `SocketError`/`Errno::*`/`OpenSSL::SSL::SSLError`/`EOFError`/`Net::HTTPBadResponse` → `raise Nfe::ApiConnectionError`.
- [ ] 2.8 `NetHttp`: descompressão gzip — se `Content-Encoding: gzip`, descomprimir via `Zlib::GzipReader` e remover o header `content-encoding`; em `Zlib::Error`, manter body cru e logar `warn`.
- [ ] 2.9 `NetHttp`: montar `Response` — `status` (Integer), `headers` normalizados para lowercase (multi-value join com `", "`), `body.force_encoding(Encoding::ASCII_8BIT)`. NÃO seguir redirect/202.
- [ ] 2.10 `NetHttp`: resetar/recriar a conexão da origem ao capturar erro de rede, para não reutilizar socket quebrado.
- [ ] 2.11 `NetHttp`: guardar o pool por origem com um `Mutex` — acesso ao cache serializado; dois threads nunca usam o mesmo socket simultaneamente (thread-safe sob Rails/Sidekiq/Puma).
- [ ] 2.12 `NetHttp`: honrar overrides por chamada do `Request` derivados de `Nfe::RequestOptions` (`base_url`/timeout/`api_key` via `X-NFE-APIKEY`) sem mutar config global nem afetar chamadas concorrentes.
- [ ] 2.13 `NetHttp`: após inflar gzip (2.8), descartar/recalcular o header `content-length` para não anunciar o tamanho comprimido obsoleto.

## 3. Retry: policy + decorator

- [ ] 3.1 Criar `lib/nfe/http/retry_policy.rb` — `Nfe::Http::RetryPolicy = Data.define(:max_retries, :base_delay, :max_delay, :jitter)`. Defaults via fábrica `.default` = `(3, 1.0, 30.0, 0.3)`. Fábrica `.none` = `max_retries: 0`.
- [ ] 3.2 `RetryPolicy#delay_for(attempt)` — `base = [base_delay * (2 ** (attempt - 1)), max_delay].min`; aplicar jitter simétrico `base * (1 - jitter + 2*jitter*rand())`, limitado a `max_delay`. `attempt` 1-based (1 = primeiro retry).
- [ ] 3.3 Criar `lib/nfe/http/retrying_transport.rb` — `Nfe::Http::RetryingTransport` decora um `inner` transport + `policy` + `sleep_fn` injetável (lambda, default `Kernel#sleep`). Implementa `call(request)`.
- [ ] 3.4 `RetryingTransport`: loop de tentativas — `inner.call(request)`; se `retryable_status?(response.status)` E `attempt < max_retries` E `request.idempotent?` → calcular delay, dormir, repetir; senão devolver `response`.
- [ ] 3.5 `RetryingTransport`: `rescue Nfe::ApiConnectionError` (inclui `TimeoutError`) — se `attempt < max_retries` E `request.idempotent?` → backoff e repetir; senão `raise`.
- [ ] 3.6 `RetryingTransport#retryable_status?` — `status == 429 || (500..599).cover?(status)`.
- [ ] 3.7 `RetryingTransport`: honrar `Retry-After` — quando o `Response` traz `retry-after` em segundos inteiros, usar `[retry_after, max_delay].min` no lugar do backoff calculado.
- [ ] 3.8 `RetryingTransport`: nunca repetir POST sem `idempotency_key` (via `request.idempotent?`), para não reemitir invoice. A `idempotency_key` é **fornecida pelo chamador** (kwarg em `create`/`create_with_state_tax`), nunca auto-gerada pelo transport; divergência de Node/PHP (que repetem POST) documentada para integradores no README (release-tooling).

## 4. User-Agent + auth header helpers

- [ ] 4.1 Criar `lib/nfe/http/user_agent.rb` — `Nfe::Http::UserAgent.build(suffix = nil)` retornando `"NFE.io Ruby Client v#{Nfe::VERSION} ruby/#{RUBY_VERSION} (#{RUBY_PLATFORM})"` + sufixo opcional.
- [ ] 4.2 Documentar (docstring) que a injeção de `User-Agent`, `X-NFE-APIKEY`, `Accept: application/json` e `Idempotency-Key` é feita pela camada `Client`/`AbstractResource` (em `add-client-core`), não pelo `NetHttp` — mantendo o transport auth-agnostic. Esta change só garante que o transport respeita os headers que o `Request` trouxer.

## 5. Hierarquia de erros

- [ ] 5.1 Criar `lib/nfe/errors.rb` — `Nfe::Error < StandardError` com `attr_reader :status_code, :request_id, :error_code, :response_body, :response_headers`. Constructor com keyword args (`status_code:`, `request_id:`, `error_code:`, `response_body:`, `response_headers: {}`).
- [ ] 5.2 `Nfe::Error#to_h` — Hash para logging (`type`, `message`, `status_code`, `request_id`, `error_code`); NÃO incluir headers que possam conter segredos sem redação.
- [ ] 5.3 Definir subclasses concretas em `lib/nfe/errors.rb`: `AuthenticationError` (401), `AuthorizationError` (403), `InvalidRequestError` (400/422), `NotFoundError` (404), `ConflictError` (409), `RateLimitError` (429), `ServerError` (5xx), `ApiConnectionError` (rede).
- [ ] 5.4 `Nfe::TimeoutError < Nfe::ApiConnectionError` — para `rescue ApiConnectionError` cobrir timeout, mas ainda discriminar.
- [ ] 5.5 `Nfe::RateLimitError` — `attr_reader :retry_after` (segundos, opcional) além dos attrs da base.
- [ ] 5.6 `Nfe::SignatureVerificationError < Nfe::Error` — definido aqui, consumido pela change de webhooks.

## 6. ErrorFactory

- [ ] 6.1 Criar `lib/nfe/error_factory.rb` — `Nfe::ErrorFactory.from_response(response)` retornando a subclasse de `Nfe::Error` apropriada por status.
- [ ] 6.2 Mapa de status (via `case`): 400/422→`InvalidRequestError`; 401→`AuthenticationError`; 403→`AuthorizationError`; 404→`NotFoundError`; 409→`ConflictError`; 429→`RateLimitError`; 500..599→`ServerError`; outros 4xx→`InvalidRequestError`; outros ≥500→`ServerError`.
- [ ] 6.3 `from_response`: extrair `message` do corpo JSON — chaves `message`/`error`/`detail`/`details`; se `errors` for String, usar; se Array, usar `errors[0]` (ou `errors[0]["message"]`). Fallback: `"API request failed with HTTP <status>"`.
- [ ] 6.4 `from_response`: extrair `error_code` — chaves `code`/`errorCode`/`error_code` (String ou Integer → String).
- [ ] 6.5 `from_response`: extrair `request_id` — header `x-request-id` (fallback `x-correlation-id`).
- [ ] 6.6 `from_response`: para 429, popular `retry_after` a partir do header `retry-after` (segundos inteiros).
- [ ] 6.7 `from_response`: `response_body` (truncado p/ log) e `response_headers` (com redação aplicada em `to_h`) preservados nos attrs.
- [ ] 6.8 `Nfe::ErrorFactory.from_network_error(exception)` — mapear `Net::OpenTimeout`/`Net::ReadTimeout`/`Timeout::Error` → `TimeoutError`; demais (`SocketError`, `Errno::*`, `OpenSSL::SSL::SSLError`) → `ApiConnectionError`, preservando `cause`.
- [ ] 6.9 Decodificação JSON resiliente — `JSON.parse` em `rescue JSON::ParserError` devolve `nil` (corpo não-JSON não derruba a factory).
- [ ] 6.10 Cap + scrub da `message` extraída do corpo — limitar a um tamanho máximo e remover caracteres de controle (a `message` ecoa input do servidor; sem cap, corpo malicioso poderia inundar log ou injetar sequências de terminal).

## 7. Logger duck-typed + redação

- [ ] 7.1 Criar `lib/nfe/http/redactor.rb` — `Nfe::Http::Redactor.headers(hash)` substitui valores de chaves sensíveis (`x-nfe-apikey`, `authorization`, `idempotency-key`, qualquer chave casando `/secret|apikey|token/i`) por `"[REDACTED]"`.
- [ ] 7.2 Integrar logging no `RetryingTransport` (e/ou em um `LoggingTransport` opcional): se `logger` presente, logar `info` no início (método + URL + headers redigidos), `warn` em retry (tentativa + delay + status/erro), `error` na falha final (status + corpo truncado).
- [ ] 7.3 Envolver toda chamada de log em `rescue StandardError` — logging nunca derruba a request.
- [ ] 7.4 Documentar que `Configuration#logger` (definido em `add-client-core`) aceita qualquer objeto que responda a `info`/`warn`/`error` (incl. `::Logger` stdlib); zero dependência.
- [ ] 7.5 **Nunca logar corpos por padrão** — entradas default só com método, URL, status e `request_id`. Log de corpo atrás de opt-in explícito (`Configuration#log_request_body`, em `add-client-core`); quando ligado, truncar e passar pela redação. Garantir que CNPJ/CPF, API key e senha de certificado nunca aparecem em nenhuma linha de log. `Nfe::Error#response_body` continua disponível, mas não é auto-logado.

## 8. Assinaturas RBS (sig/)

- [ ] 8.1 `sig/nfe/http/request.rbs` — assinatura de `Nfe::Http::Request` (`Data` com os 9 campos) + `#url`, `#idempotent?`.
- [ ] 8.2 `sig/nfe/http/response.rbs` — `Nfe::Http::Response` + `#header`, `#success?`, `#location`.
- [ ] 8.3 `sig/nfe/http/transport.rbs` — `interface _Transport { def call: (Request) -> Response }` + módulo.
- [ ] 8.4 `sig/nfe/http/net_http.rbs`, `sig/nfe/http/retrying_transport.rbs`, `sig/nfe/http/retry_policy.rbs`, `sig/nfe/http/user_agent.rbs`, `sig/nfe/http/redactor.rbs`.
- [ ] 8.5 `sig/nfe/errors.rbs` — `Nfe::Error` + todas as subclasses, com attrs tipados.
- [ ] 8.6 `sig/nfe/error_factory.rbs` — `from_response`/`from_network_error`.
- [ ] 8.7 Rodar `steep check` — 0 erros nas assinaturas novas.

## 9. Testes (RSpec, SimpleCov >= 80%)

- [ ] 9.1 `spec/support/fake_transport.rb` — transport fake que responde a `call(request)`, com fila de `Response`s/erros enfileirados e registro das `Request`s recebidas (para asserts).
- [ ] 9.2 `spec/nfe/http/request_spec.rb` — `#url` (com/sem query, query repetida, path já com `?`), `#idempotent?` (GET/PUT/DELETE true, POST false, POST+idempotency_key true).
- [ ] 9.3 `spec/nfe/http/response_spec.rb` — `#header` case-insensitive, `#success?` (2xx vs 3xx/4xx), `#location`, body binário preservado.
- [ ] 9.4 `spec/nfe/http/retry_policy_spec.rb` — `delay_for` respeita cap `max_delay`, jitter dentro de `[base*(1-j), base*(1+j)]`, `.none` não dá delay.
- [ ] 9.5 `spec/nfe/http/retrying_transport_spec.rb` — 503→503→200 (sucesso transparente, sleep injetado), 400 não repete, retries esgotados devolvem último 503 (vira `ServerError` na camada de recurso), 429 com `Retry-After: 5` aguarda >= 5s, POST sem idempotency_key não repete, GET repete, erro de rede repete e propaga após esgotar.
- [ ] 9.6 `spec/nfe/http/net_http_spec.rb` — usando WEBrick/`Net::HTTP` contra servidor local stub (stdlib, sem dep): GET/POST básico, header lowercase, gzip descomprimido, 202 + Location preservados, timeout → `TimeoutError`, conexão recusada → `ApiConnectionError`, TLS verify on por default.
- [ ] 9.7 `spec/nfe/http/user_agent_spec.rb` — formato `NFE.io Ruby Client v<version> ruby/<v> (<platform>)` + sufixo.
- [ ] 9.8 `spec/nfe/http/redactor_spec.rb` — `X-NFE-APIKEY`/`Authorization`/`Idempotency-Key`/chaves `*secret*`/`*token*` viram `[REDACTED]`; chaves benignas intactas.
- [ ] 9.9 `spec/nfe/errors_spec.rb` — attrs da base, `to_h` sem segredos, `TimeoutError` é `ApiConnectionError`, `RateLimitError#retry_after`.
- [ ] 9.10 `spec/nfe/error_factory_spec.rb` — cada status → classe correta (400, 401, 403, 404, 409, 422, 429, 500, 502, 599, 418 fallback); extração de `message`/`error_code`/`request_id`; corpo não-JSON não quebra; `from_network_error` mapeia timeout vs conexão.
- [ ] 9.11 Logging — spec verifica que com logger duck-typed presente há `error` em falha e `warn` em retry, com headers redigidos; sem logger não há chamada nem dependência.
- [ ] 9.12 Logging sem corpos — spec verifica que por padrão nenhuma linha de log contém corpo de request/response, CNPJ/CPF, API key ou senha de certificado (só método/URL/status/`request_id`); com `log_request_body` ligado, corpo é truncado e redigido.
- [ ] 9.13 Thread-safety — spec exerce o `NetHttp` (ou fake) a partir de múltiplos threads concorrentes contra a mesma origem e verifica que o pool guardado por `Mutex` não corrompe nem compartilha socket.
- [ ] 9.14 Per-call options — spec verifica que um `Request` com override de `base_url`/timeout/`api_key` (via `Nfe::RequestOptions`) é roteado/autenticado por chamada sem afetar a config global nem outras chamadas.
- [ ] 9.15 Hardening — spec verifica cap+scrub da `message` (corpo longo/com controle) e que `content-length` é descartado/recalculado após inflar gzip.

## 10. Validação end-to-end

- [x] 10.1 `bundle exec rspec` — toda a suite verde (128 exemplos / 0 falhas), cobertura de linha ~97.5% (docker 3.2/3.3/3.4).
- [x] 10.2 `bundle exec steep check` — 0 erros (docker 3.2/3.3/3.4).
- [x] 10.3 `bundle exec rubocop` — 0 offenses; `# frozen_string_literal: true` em todo `.rb` novo (docker 3.2/3.3/3.4).
- [x] 10.4 `openspec validate add-http-transport` — passa.
- [x] 10.5 Zero require de gem externa nos arquivos novos — só stdlib (`net/http`, `json`, `openssl`, `uri`, `zlib`, `stringio`).

## 11. Documentação

- [ ] 11.1 Docstrings (YARD-style) em `Transport` (como implementar), `NetHttp`, `RetryingTransport`, `RetryPolicy`, `ErrorFactory` e em cada classe de erro.
- [ ] 11.2 Nota no README (seção HTTP) — caminho default (`NetHttp` zero-dep) e como plugar um transport custom (qualquer objeto com `#call`) — **pode ser consolidado na change de release-tooling**.
- [ ] 11.3 Documentar `Configuration#ca_file` como escape hatch para CA store legado (a config em si vive em `add-client-core`).

## 12. Smoke test manual (opt-in, fora do CI)

- [ ] 12.1 GET real contra um host NFE.io retornando 200 + JSON (com chave sandbox) — **DEFERRED** (precisa chave).
- [ ] 12.2 Download real (PDF) retornando bytes começando com `%PDF` via `Response#body` binário — **DEFERRED**.
- [ ] 12.3 Forçar 429 (ou simular) e verificar honra de `Retry-After` — **DEFERRED**.
- [ ] 12.4 Registrar resultados em `.notes/http-transport-smoke.md` — **DEFERRED**.
