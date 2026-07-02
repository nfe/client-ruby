# Design — add-http-transport

## Context

A camada HTTP é o alicerce de todo o SDK v1. O rewrite é greenfield: nada do v0.3.2 (rest-client, congelado em `0.x-legacy`) é reaproveitado. As restrições canônicas que moldam cada decisão aqui:

1. **Zero dependências de runtime** — apenas stdlib. O transport default é `Net::HTTP`; nada de Faraday/HTTParty/rest-client.
2. **Múltiplas base URLs** — a NFE.io distribui a API por ~6 hosts. Hardcodar host é insustentável. Cada `Request` carrega seu `base_url`; o transport não conhece host nenhum. O **mapa de hosts** em si mora em `Nfe::Configuration` (na change `add-client-core`), não aqui — esta change só garante que o transport respeita o `base_url` que recebe.
3. **202 + `Location`** — emissões assíncronas respondem 202 com `Location` apontando para o recurso final. O transport NÃO segue; expõe `status` e `Location` crus. O contrato discriminado `Pending`/`Issued` mora em `add-client-core`.
4. **Downloads binários** — PDF/XML/ZIP voltam como bytes. O `Response#body` é uma String binary-safe (`ASCII-8BIT`); a camada de recurso faz `force_encoding(Encoding::ASCII_8BIT)` quando o método é um download.
5. **Falhas transientes** — 429 com `Retry-After`, 5xx, timeouts e quedas de DNS/TLS são realidade. Sem retry policy, integrações falham em produção sem motivo legítimo.
6. **Testabilidade** — para testar recurso sem rede, o `Transport` é uma interface duck-typed substituível por um fake com fila de respostas.

Referências de paridade: `client-nodejs/src/core/http/client.ts` (auth header `X-NFE-APIKEY`, processamento de 202, retry com backoff + jitter 10%, `parseResponseData` por content-type) e `client-php` `src/Http/*` + `src/Exception/*` (transport interface, `RetryingTransport` decorator, `RetryPolicy` com jitter ±30%, `ErrorFactory`, hierarquia plana de exceptions). Adaptamos ambos para Ruby idiomático.

## Goals / Non-Goals

**Goals**
- Contrato `Transport` duck-typed substituível por fake/mock em testes.
- Default `Net::HTTP` zero-dep funcionando out-of-the-box com TLS verificado.
- Value objects imutáveis (`Data.define`) para `Request`/`Response`/`RetryPolicy`.
- Reuso de conexão persistente por origem (keep-alive) e timeouts open/read separados.
- gzip transparente (request `Accept-Encoding: gzip`, response descomprimida).
- Retry com backoff exponencial + jitter para 429/5xx/rede, **só em métodos idempotentes**, honrando `Retry-After`.
- Hierarquia de erros tipados consumível com `rescue Nfe::NotFoundError` e `ErrorFactory` que mapeia status + corpo.
- User-Agent honesto; auth via `X-NFE-APIKEY`.
- Logger duck-typed (PSR-3-equivalente) com redação de segredos.
- Slot de `Idempotency-Key` (campo no `Request`, envio condicional).
- 202 expõe `Location` cru para a camada de cima.

**Non-Goals**
- Polling (`pollUntilComplete`/`create_and_wait`) — diferido; contrato 202 nasce correto, helper vem depois.
- Concorrência/`createBatch` — Ruby síncrono não ganha nada aqui.
- Async/fibers, HTTP/2 server push, streaming download para disco, websockets.
- Cache de respostas, métricas automáticas.
- OAuth2 — a NFE.io usa chave de API (`X-NFE-APIKEY`); suficiente.
- O **host map** multi-base-URL em si — vive em `Nfe::Configuration` (`add-client-core`). Aqui só respeitamos `Request#base_url`.

## Decisions

### D1. Transport como interface duck-typed, não classe abstrata
**Decisão**: `Nfe::Http::Transport` é um módulo documental com `def call(request); raise NotImplementedError; end`. Qualquer objeto que responda a `call(Request) -> Response` é um transport válido. O default é `Nfe::Http::NetHttp`; o decorator é `Nfe::Http::RetryingTransport`; testes usam um fake com fila.

**Por quê**: Ruby é duck-typed; forçar herança seria não-idiomático. Espelha o `Transport` do PHP (interface de método único `send`) mas sem o peso de `interface`. O nome do método é `call` (idioma Ruby para objetos invocáveis), em vez de `send` (que colide com `Object#send`).

**Alternativa rejeitada**: classe abstrata com `raise NotImplementedError` em métodos — mais verboso, sem ganho.

### D2. `Net::HTTP` como transport default, conexão persistente por origem
**Decisão**: `Nfe::Http::NetHttp` mantém um cache de instâncias `Net::HTTP` por `"#{host}:#{port}"`, com `start` mantido aberto (`keep_alive_timeout`) para reusar conexão TCP/TLS entre chamadas ao mesmo host. TLS sempre com `use_ssl = true` (para `https`), `verify_mode = OpenSSL::SSL::VERIFY_PEER`, usando o CA store do sistema (sem versionar bundle CA).

**Por quê**: A NFE.io tem ~6 hosts; cada recurso bate sempre no mesmo. Reaproveitar a conexão TLS por host elimina o custo de handshake repetido. Um `Net::HTTP` por origem é o pool natural do `Net::HTTP` (que não é multi-host).

**Por quê não versionar CA bundle**: Ruby 3.2+ usa o CA store do sistema; versionar bundle adiciona peso e dívida de manutenção. Documentar `Configuration#ca_file` como escape hatch para ambientes legados.

### D3. `Request`/`Response`/`RetryPolicy` como `Data.define` imutáveis
**Decisão**: usar `Data.define` (Ruby 3.2+) em vez de `Struct` ou classe manual.

```ruby
Request = Data.define(:method, :base_url, :path, :headers, :query, :body,
                      :open_timeout, :read_timeout, :idempotency_key) do
  def url = ... # base_url + path + URI.encode_www_form(query)
end

Response = Data.define(:status, :headers, :body) do
  def header(name) = headers[name.downcase]
  def success?     = (200..299).cover?(status)
  def location     = header("location")
end
```

**Por quê**: `Data.define` dá imutabilidade real, `==` por valor, `with` para cópias, e keyword args — exatamente o que os value objects `readonly` do PHP entregam, mas idiomático em Ruby. Headers de `Response` são normalizados para **chaves lowercase** (HTTP headers são case-insensitive; espelha `Response#header` do PHP e `response.headers['location']` do Node).

### D4. `Response#body` é String binary-safe (`ASCII-8BIT`)
**Decisão**: o transport não tenta decodificar/parsear o body. Devolve a String crua de bytes, com `force_encoding(Encoding::ASCII_8BIT)`. JSON parsing e `force_encoding` final ficam na camada de recurso (que sabe se é download binário ou JSON).

**Por quê**: paridade com a regra canônica "downloads return raw bytes as a binary-safe String". Em Ruby uma String com encoding `ASCII-8BIT` é binary-safe; o caller faz `File.binwrite` ou `JSON.parse(body)` conforme o método. Centralizar parsing no transport (como o `parseResponseData` por content-type do Node) acoplaria o transport ao conhecimento de cada endpoint — preferimos manter o transport burro.

**Trade-off**: gzip É descomprimido no transport (porque é uma camada de transporte, não de aplicação) — ver D5.

### D5. gzip transparente no transport
**Decisão**: o transport injeta `Accept-Encoding: gzip` (a menos que o caller já tenha setado um `Accept-Encoding`), e descomprime a resposta quando `Content-Encoding: gzip`, removendo o header `content-encoding` do `Response` resultante (já que o body devolvido está descomprimido). `Net::HTTP` faz isso automaticamente se não setarmos `Accept-Encoding` manualmente; setamos explicitamente e tratamos via `Zlib::GzipReader` para controle determinístico e para que downloads também se beneficiem.

**Por quê**: gzip é transporte, não semântica. O recurso não deve ver bytes comprimidos. `zlib` é stdlib (permitido implicitamente por `net/http`).

### D6. Auth via `X-NFE-APIKEY`, injetado pela camada
**Decisão**: o header de autenticação é `X-NFE-APIKEY: <api_key>` (paridade exata com Node `buildHeaders`). A injeção do header acontece quando o `Client`/`AbstractResource` (em `add-client-core`) constrói o `Request`, não dentro do `NetHttp` — assim `NetHttp` e qualquer transport custom se beneficiam e o transport fica auth-agnostic.

**Por quê**: espelha o refinamento do PHP (UA/auth injetados na camada `Client`, não no `CurlTransport`). Mantém o transport como pura mecânica de rede.

**Nota**: a resolução `api_key` vs `data_api_key` por família de host é responsabilidade de `add-client-core`; aqui só documentamos que o header carrega a chave que o `Request` trouxer.

### D7. User-Agent honesto
**Decisão**: `NFE.io Ruby Client v<version> ruby/<RUBY_VERSION> (<RUBY_PLATFORM>)`, ex.: `NFE.io Ruby Client v1.0.0 ruby/3.3.0 (x86_64-linux)`. Versão lida de `Nfe::VERSION`. Helper em `Nfe::Http::UserAgent.build(suffix = nil)`.

**Por quê**: Stripe, Node e PHP fazem telemetria honesta de UA. Ajuda o time NFE.io a saber de qual SDK/versão vem cada chamada.

### D8. Retry: 3 tentativas, base 1s, max 30s, jitter ±30%, só idempotente
**Decisão**: `RetryPolicy` default = `max_retries: 3, base_delay: 1.0, max_delay: 30.0, jitter: 0.3`. `RetryingTransport` decora qualquer transport e faz retry em:
- HTTP **429** (sempre, com backoff)
- HTTP **5xx** (500–599)
- **Erros de rede** (`Nfe::ApiConnectionError`/`Nfe::TimeoutError` levantados pelo transport interno)

NÃO faz retry em 4xx exceto 429. Faz retry **apenas para métodos idempotentes** (`GET`, `HEAD`, `PUT`, `DELETE`) — ou para qualquer método que carregue um `Idempotency-Key`. POST sem idempotency-key NÃO é repetido (evita emitir invoice duplicada).

`delay(n) = min(max_delay, base_delay * 2^(n-1)) * (1 - jitter + 2*jitter*rand())`. Honra `Retry-After` (segundos inteiros) com precedência sobre o backoff calculado, limitado a `max_delay`. `sleep` é injetável (`Closure`/lambda) para testes determinísticos.

**Por quê**: defaults alinhados a Stripe/Node/PHP. A regra "só idempotente" é mais segura que o Node (que repete qualquer não-4xx-não-429): emitir NFS-e/NF-e é POST não idempotente; repetir cegamente poderia gerar nota duplicada. O slot de `Idempotency-Key` (D9) destrava retry seguro de POST quando a API suportar.

**Alternativa rejeitada**: replicar o Node 1:1 (retry de qualquer não-4xx). Rejeitada por risco de emissão duplicada.

### D9. Idempotency-Key como slot, envio condicional
**Decisão**: `Request` tem o campo `idempotency_key`. Quando presente, o transport envia `Idempotency-Key: <valor>`. A geração (`SecureRandom.uuid`) e a decisão de *quando* habilitar ficam na camada de recurso (`add-client-core`+); por padrão é `nil` (não enviado).

**Por quê**: o task de escopo pede "idempotency-key support where the API allows it". Diferente do PHP (que removeu o slot por completo), aqui mantemos o **campo** porque (a) `securerandom` está na allowlist de stdlib e (b) destrava retry seguro de POST. Se a API NFE.io ainda não honra o header, o custo é zero (campo `nil`); quando honrar, é só a camada de recurso passar a chave — mudança aditiva não-breaking.

### D10. Hierarquia de erros plana sob `Nfe::Error`
**Decisão**: 1 nível de herança. `Nfe::Error < StandardError` é a base; as subclasses concretas herdam direto dela. A informação detalhada mora em **attrs**, não em subclasses.

```ruby
module Nfe
  class Error < StandardError
    attr_reader :status_code, :request_id, :error_code, :response_body, :response_headers
    def initialize(message = nil, status_code: nil, request_id: nil,
                   error_code: nil, response_body: nil, response_headers: {})
      ...
    end
    def to_h = { ... } # logging
  end

  class AuthenticationError       < Error; end  # 401
  class AuthorizationError        < Error; end  # 403
  class InvalidRequestError       < Error; end  # 400 / 422
  class NotFoundError             < Error; end  # 404
  class ConflictError             < Error; end  # 409
  class RateLimitError            < Error; end  # 429 (carrega retry_after)
  class ServerError               < Error; end  # 5xx
  class ApiConnectionError        < Error; end  # rede (DNS/TLS/socket)
  class TimeoutError              < ApiConnectionError; end # open/read timeout
  class SignatureVerificationError < Error; end # webhooks (consumido depois)
end
```

**Por quê**: `rescue Nfe::Error` pega tudo; `rescue Nfe::NotFoundError` pega o específico. Plano e fácil de consumir — espelha a decisão D6 do PHP. `TimeoutError < ApiConnectionError` permite `rescue Nfe::ApiConnectionError` cobrir timeouts (semântica de rede), mas ainda discriminar timeout. Cobre a união Node (`ValidationError`/`AuthenticationError`/`NotFoundError`/`ConflictError`/`RateLimitError`/`ServerError`/`ConnectionError`/`TimeoutError`) + PHP (`AuthorizationException` 403, `SignatureVerificationException`).

**Nomenclatura**: usamos `InvalidRequestError` (estilo PHP/Stripe) em vez de `ValidationError` (Node), porque o escopo da change pede `InvalidRequestError(400/422)`. O 422 (Unprocessable Entity) também mapeia para `InvalidRequestError`.

### D11. `ErrorFactory` mapeia status + corpo → erro tipado
**Decisão**: `Nfe::ErrorFactory.from_response(response)` e `Nfe::ErrorFactory.from_network_error(exception)`. O primeiro decide a classe por `status` (`case` em Ruby), extrai `message` do corpo JSON (chaves `message`/`error`/`detail`/`details`/`errors[0]`), `error_code` (chaves `code`/`errorCode`/`error_code`), e `request_id` do header `x-request-id` (fallback `x-correlation-id`). O segundo mapeia exceptions de `Net::HTTP`/socket para `ApiConnectionError`/`TimeoutError`.

Mapa de status:

| Status | Erro |
|---|---|
| 400, 422 | `InvalidRequestError` |
| 401 | `AuthenticationError` |
| 403 | `AuthorizationError` |
| 404 | `NotFoundError` |
| 409 | `ConflictError` |
| 429 | `RateLimitError` (+ `retry_after`) |
| 5xx | `ServerError` |
| outros 4xx | `InvalidRequestError` (fallback) |
| outros ≥500 | `ServerError` (fallback) |

**Por quê**: espelha `ErrorFactory::fromResponse` (PHP) e `ErrorFactory.fromHttpResponse` (Node). O `request_id` é uma adição sobre o PHP/Node — facilita suporte/debug (o task pede `request_id` explicitamente).

### D12. Onde os erros são levantados (factory na camada de recurso, não no transport)
**Decisão**: `NetHttp#call` **não** levanta para 4xx/5xx — devolve o `Response` com o status. Quem levanta é a camada de recurso/`AbstractResource` (em `add-client-core`), chamando `ErrorFactory.from_response`. O `NetHttp` só levanta `ApiConnectionError`/`TimeoutError` para falhas de **rede** (não há `Response`).

**Por quê**: espelha o contrato do `Transport` do PHP ("HTTP-level errors são retornados como Response para a retry layer e a exception factory agirem"). Permite que o `RetryingTransport` veja o status 429/5xx e decida retry **antes** de virar exceção. Só vira exceção depois de esgotado o retry.

### D13. Logger duck-typed com redação de segredos
**Decisão**: `Configuration#logger` (de `add-client-core`) é qualquer objeto que responda a `info`/`warn`/`error` — incluindo `::Logger` da stdlib. O transport/decorator, quando recebe um logger, loga: início do request (`info`: método + URL + headers redigidos), retry (`warn`: tentativa + delay + status/erro), e falha final (`error`: status + corpo truncado). **Redação obrigatória**: `X-NFE-APIKEY`, `Authorization`, `Idempotency-Key` e qualquer chave contendo `secret`/`apikey`/`token` (case-insensitive) viram `[REDACTED]` antes de qualquer log.

**Por quê**: PSR-3 não existe em Ruby; o equivalente idiomático é duck-typing sobre a interface de `::Logger`. Zero dependência. A redação é requisito de compliance (tratar tudo como sensível, nunca expor chaves) — vale para a NFE.io.

### D14. 202 e redirects não são seguidos
**Decisão**: `NetHttp` configura para NÃO seguir redirects e devolve 202 cru com `Location` no `Response`. `Net::HTTP` não segue redirect por padrão (diferente de cURL `FOLLOWLOCATION`), então só garantimos não tratar 3xx como erro nem seguir.

**Por quê**: o recurso é quem sabe se 202 vira `Pending` (com `Location`) ou se um 201 vira `Issued`. Seguir no transport esconderia a semântica. Espelha D5 do PHP e o `processResponse` do Node (que extrai `location` mas não busca).

### D15. Pool de conexão por origem é thread-safe (Mutex) — DECISÃO (antes era Open Question)
**Decisão**: o cache de instâncias `Net::HTTP` por `"#{host}:#{port}"` dentro de `NetHttp` é guardado por um `Mutex`. Um `Client` compartilhado (que injeta um único transport) é **thread-safe** sob execução concorrente: o acesso ao pool é serializado e dois threads nunca usam o mesmo socket simultaneamente. Isso torna o `Client` seguro em Rails/Sidekiq/Puma multi-thread.

**Por quê**: a decisão de manutenção colocou thread-safety em escopo para v1 (não é mais "instancie um Client por thread"). `Mutex` é stdlib, custo desprezível, e remove uma pegadinha clássica de SDK. Complementa o guard de acessores memoizados no `Client` (em `add-client-core`).

### D16. Overrides por chamada via `Nfe::RequestOptions`
**Decisão**: o transport honra overrides por chamada (`api_key`/`base_url`/`timeout`) carregados no `Request` a partir de `Nfe::RequestOptions` (`Data.define`, definido em `add-client-core`). Uma chamada com override roteia para o `base_url` alternativo, usa o timeout alternativo e envia a `api_key` alternativa em `X-NFE-APIKEY`, **sem** mutar a configuração global nem afetar outras chamadas concorrentes.

**Por quê**: habilita multi-tenant (uma `api_key` por chamada) sem um segundo `Client`. Como `Request` já é imutável (`Data.define`), o override é só um `Request` diferente — o transport permanece burro e auth-agnostic (D6).

### D17. Logger nunca emite BODIES por padrão
**Decisão**: além da redação de headers (D13), o transport por padrão **não loga corpos** de request/response. As entradas default contêm só método, URL, status e `request_id`. Log de corpo fica atrás de um opt-in explícito (`Configuration#log_request_body`, em `add-client-core`); quando ligado, o corpo é truncado e passa pela redação. `Nfe::Error#response_body` continua disponível para inspeção programática, mas **não** é auto-logado.

**Por quê**: compliance — CNPJ/CPF e a senha do certificado nunca devem vazar em log. Tratar tudo como sensível; o opt-in é decisão consciente do integrador, com truncamento e redação mesmo assim.

### D18. Hardening barato: cap/scrub de mensagem de erro + Content-Length pós-gzip
**Decisão**: (a) `ErrorFactory` limita a `message` extraída do corpo a um tamanho máximo e remove caracteres de controle (a `message` ecoa input do servidor; sem cap, um corpo malicioso poderia inundar logs ou injetar sequências de terminal). (b) Após inflar gzip (D5), o transport **descarta ou recalcula** o header `content-length`, que passaria a anunciar o tamanho comprimido obsoleto.

**Por quê**: dois one-liners de robustez sem custo de dependência; alinhados ao princípio de tratar todo input externo como hostil.

| Risco | Mitigação |
|---|---|
| `Net::HTTP` parseia status/headers de forma diferente de cURL/fetch | Normalizar headers para lowercase no `Response`; testes cobrem multi-value join e `Location` |
| Conexão persistente vaza socket entre hosts ou após erro | Pool por `host:port`; resetar/recriar a conexão em `ApiConnectionError`; `keep_alive_timeout` curto |
| Retry de POST poderia emitir invoice duplicada | Retry só em métodos idempotentes (GET/HEAD/PUT/DELETE) ou POST com `Idempotency-Key` (D8/D9) |
| gzip mal-formado quebra descompressão | Tratar `Zlib::Error` como corpo cru (fallback) e logar `warn` |
| User-Agent revela versão de Ruby/plataforma (info disclosure?) | Aceitável — Stripe/Node/PHP fazem o mesmo; é norma de telemetria honesta |
| Logger custom pode levantar dentro do log | Envolver chamadas de log em `rescue StandardError` para nunca derrubar a request por causa de logging |
| Verificação TLS falha em ambiente com CA store desatualizado | `Configuration#ca_file` como escape hatch documentado; nunca desabilitar `VERIFY_PEER` por default |
| `Retry-After` em formato HTTP-date (não segundos) | v1 suporta só segundos inteiros (paridade PHP); HTTP-date cai no backoff calculado |

## Open Questions

- (nenhuma) — a thread-safety do pool foi resolvida (ver D15).

## Resolved (durante o recon — 2026-06-24)

- **Header de auth confirmado**: `X-NFE-APIKEY` (não `Authorization: Basic`). Confirmado em `client-nodejs/src/core/http/client.ts:287`.
- **Estados terminais de FlowStatus** (relevantes para o consumidor do 202, mas implementados em `add-client-core`): `Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`. Esta change só garante que 202 + `Location` chegam crus à camada de cima.
- **`Idempotency-Key`**: diferente do PHP (que removeu), mantemos o campo no `Request` por estar na allowlist (`securerandom`) e por destravar retry seguro de POST. Envio condicional — `nil` por padrão, custo zero se a API não honrar.
