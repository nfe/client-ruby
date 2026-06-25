# http-transport Specification

## Purpose
TBD - created by archiving change add-http-transport. Update Purpose after archive.
## Requirements
### Requirement: Transport abstraction
The SDK SHALL define a transport contract `Nfe::Http::Transport` exposing a single method `call(request) -> response`, allowing the HTTP transport implementation to be substituted (default `Net::HTTP`, PSR-3-style logging decorator, or an in-memory fake) without touching resource code. Any object responding to `call(Nfe::Http::Request)` and returning an `Nfe::Http::Response` SHALL be a valid transport (duck typing).

#### Scenario: Substituting the transport for tests
- **WHEN** a test constructs the SDK with a fake object whose `call` returns queued `Nfe::Http::Response` instances
- **THEN** all HTTP requests SHALL be routed through that fake without reaching the network

#### Scenario: Transport returns HTTP errors as responses, not exceptions
- **WHEN** a transport receives an HTTP 404 or HTTP 500 from the wire
- **THEN** it SHALL return an `Nfe::Http::Response` carrying that status code, and SHALL NOT raise — so the retry decorator and `Nfe::ErrorFactory` can act on the status

### Requirement: Default zero-dependency Net::HTTP transport
The SDK SHALL ship `Nfe::Http::NetHttp` as the default transport, implemented using only the Ruby standard library (`net/http`, `uri`, `openssl`, `zlib`, `stringio`). It SHALL NOT require any external gem.

#### Scenario: Using the SDK without any HTTP gem installed
- **WHEN** a consumer installs `nfe-io` and uses the client without configuring a transport
- **THEN** the SDK SHALL use `Nfe::Http::NetHttp` and perform HTTP requests successfully against the network

#### Scenario: TLS verification is enforced by default
- **WHEN** `Nfe::Http::NetHttp` sends a request to an `https` base URL
- **THEN** it SHALL enable TLS with `OpenSSL::SSL::VERIFY_PEER` and SHALL NOT disable certificate verification

#### Scenario: Persistent connection reuse per origin
- **WHEN** two consecutive requests target the same `host:port`
- **THEN** the transport SHALL reuse a single persistent `Net::HTTP` connection (keep-alive) for that origin rather than opening a new TCP/TLS connection each time

### Requirement: Request value object
The SDK SHALL define `Nfe::Http::Request` as an immutable value object (`Data.define`) carrying `method`, `base_url`, `path`, `headers`, `query`, `body`, `open_timeout`, `read_timeout`, and `idempotency_key`. It SHALL expose `#url` composing the final URL from `base_url`, `path`, and the URL-encoded `query`, and `#idempotent?` returning true for `GET`/`HEAD`/`PUT`/`DELETE` (case-insensitive) or any request carrying an `idempotency_key`.

#### Scenario: URL composition with query
- **WHEN** a `Request` has `base_url: "https://api.nfse.io"`, `path: "/v2/companies/abc/productinvoices"`, and `query: { environment: "Production", limit: 50 }`
- **THEN** `#url` SHALL return `https://api.nfse.io/v2/companies/abc/productinvoices?environment=Production&limit=50`

#### Scenario: Idempotency classification
- **WHEN** `#idempotent?` is called on a `GET`, `HEAD`, `PUT`, or `DELETE` request, or on a `POST` request carrying a non-nil `idempotency_key`
- **THEN** it SHALL return `true`; for a `POST` request with no `idempotency_key` it SHALL return `false`

### Requirement: Response value object
The SDK SHALL define `Nfe::Http::Response` as an immutable value object (`Data.define`) carrying `status` (Integer), `headers` (Hash with lowercase string keys), and `body` (a binary-safe `ASCII-8BIT` String). It SHALL expose `#header(name)` (case-insensitive lookup), `#success?` (true for 2xx), and `#location` (the `Location` header or nil).

#### Scenario: Case-insensitive header lookup
- **WHEN** a server returns a `Location:` header in any letter casing
- **THEN** `#header("Location")`, `#header("location")`, and `#location` SHALL all return the same value

#### Scenario: Body is binary-safe
- **WHEN** the response body contains raw PDF or ZIP bytes
- **THEN** `body` SHALL be a String with `ASCII-8BIT` encoding, preserving every byte without transcoding

### Requirement: Multi-base-URL routing
The SDK SHALL allow each `Nfe::Http::Request` to specify its `base_url` independently, so resources targeting different NFE.io hosts (`api.nfe.io`, `api.nfse.io`, `address.api.nfe.io/v2`, `nfe.api.nfe.io`, `legalentity.api.nfe.io`, `naturalperson.api.nfe.io`) work uniformly through the same transport. The transport SHALL NOT hard-code any host. The host map itself is owned by `Nfe::Configuration` (defined in change `add-client-core`); this capability only requires that the transport honors the `base_url` it receives.

#### Scenario: A resource targets a non-default host
- **WHEN** a resource constructs `Nfe::Http::Request.new(method: "GET", base_url: "https://api.nfse.io", path: "/v2/...")`
- **THEN** the transport SHALL send the request to `api.nfse.io` regardless of any global default base URL

### Requirement: gzip transport encoding
The transport SHALL request `Accept-Encoding: gzip` (unless the caller already set an `Accept-Encoding` header) and SHALL transparently decompress a `Content-Encoding: gzip` response body before returning it, removing the `content-encoding` header from the resulting `Response`.

#### Scenario: Compressed JSON response
- **WHEN** the server returns a body with `Content-Encoding: gzip`
- **THEN** the `Response#body` SHALL contain the decompressed bytes and `Response#header("content-encoding")` SHALL be nil

#### Scenario: Content-Length reflects the decompressed body
- **WHEN** a `Content-Encoding: gzip` body is inflated
- **THEN** the transport SHALL drop or recompute the `content-length` header so it does not advertise the now-stale compressed byte count

#### Scenario: Malformed gzip falls back to raw bytes
- **WHEN** the server claims `Content-Encoding: gzip` but the body cannot be inflated
- **THEN** the transport SHALL return the raw body unchanged and SHALL log a warning if a logger is configured, without raising

### Requirement: Retry policy with exponential backoff and jitter
The SDK SHALL provide `Nfe::Http::RetryPolicy` (`Data.define`) with configurable `max_retries` (default 3), `base_delay` (default 1.0s), `max_delay` (default 30.0s), and `jitter` (default 0.3 = ±30%), plus factories `.default` and `.none`. `#delay_for(attempt)` SHALL compute `min(max_delay, base_delay * 2^(attempt-1))` and apply symmetric jitter, capped at `max_delay`.

#### Scenario: Backoff is capped
- **WHEN** `#delay_for` is called for an attempt large enough that the exponential term exceeds `max_delay`
- **THEN** the returned delay SHALL NOT exceed `max_delay`

#### Scenario: Jitter bounds
- **WHEN** `#delay_for(attempt)` is called repeatedly with `jitter: 0.3`
- **THEN** every returned value SHALL fall within `[base * 0.7, base * 1.3]` (clamped to `max_delay`), where `base = min(max_delay, base_delay * 2^(attempt-1))`

#### Scenario: No-retry policy
- **WHEN** the policy is `RetryPolicy.none`
- **THEN** `max_retries` SHALL be 0 and the retrying transport SHALL make exactly one HTTP attempt

### Requirement: Retrying transport for transient failures on idempotent requests
The SDK SHALL provide `Nfe::Http::RetryingTransport`, a decorator wrapping any transport with a `RetryPolicy` and an injectable sleep function. It SHALL retry on HTTP 429, HTTP 500–599, and network errors (`Nfe::ApiConnectionError`, including `Nfe::TimeoutError`), but ONLY for idempotent requests (per `Request#idempotent?`). It SHALL NOT retry HTTP 4xx other than 429, and SHALL NOT retry a non-idempotent `POST`.

#### Scenario: Server returns 503 then succeeds
- **WHEN** the inner transport returns HTTP 503 on a `GET` then HTTP 200 on retry
- **THEN** the retrying transport SHALL transparently return the successful 200 response to the caller

#### Scenario: Client error other than 429 is not retried
- **WHEN** the inner transport returns HTTP 400
- **THEN** the retrying transport SHALL return that 400 response immediately without retrying

#### Scenario: Non-idempotent POST is not retried
- **WHEN** the inner transport returns HTTP 503 for a `POST` request that carries no `idempotency_key`
- **THEN** the retrying transport SHALL return the 503 response without retrying, so the SDK never re-issues an invoice

#### Scenario: Retries exhausted
- **WHEN** the inner transport returns HTTP 503 on every attempt for an idempotent request up to the configured maximum
- **THEN** the retrying transport SHALL return the last 503 response (which the resource layer maps to `Nfe::ServerError`)

#### Scenario: Retry-After honored
- **WHEN** the inner transport returns HTTP 429 with `Retry-After: 5` for an idempotent request
- **THEN** the retrying transport SHALL wait at least 5 seconds (clamped to `max_delay`) before the next attempt

#### Scenario: Network error is retried then propagated
- **WHEN** the inner transport raises `Nfe::ApiConnectionError` on every attempt for an idempotent request
- **THEN** the retrying transport SHALL retry up to `max_retries` and then re-raise the last `Nfe::ApiConnectionError`

### Requirement: Error hierarchy
The SDK SHALL define an error hierarchy rooted at `Nfe::Error` (subclass of `StandardError`), with concrete subclasses: `AuthenticationError` (401), `AuthorizationError` (403), `InvalidRequestError` (400/422), `NotFoundError` (404), `ConflictError` (409), `RateLimitError` (429), `ServerError` (5xx), `ApiConnectionError` (network), `TimeoutError` (a subclass of `ApiConnectionError`), and `SignatureVerificationError` (webhook verification). `Nfe::Error` SHALL expose `status_code`, `request_id`, `error_code`, `response_body`, and `response_headers`, plus a `#to_h` for logging.

#### Scenario: Catching a specific error
- **WHEN** consumer code wraps a call with `rescue Nfe::NotFoundError`
- **THEN** the SDK SHALL raise that error specifically on HTTP 404 responses, not the base class

#### Scenario: Catching all SDK errors
- **WHEN** consumer code wraps a call with `rescue Nfe::Error`
- **THEN** every SDK-raised error SHALL be caught through this base class

#### Scenario: Timeout is a connection error
- **WHEN** consumer code wraps a call with `rescue Nfe::ApiConnectionError`
- **THEN** it SHALL also catch `Nfe::TimeoutError`, since `TimeoutError` is a subclass of `ApiConnectionError`

#### Scenario: Error carries response context
- **WHEN** any `Nfe::Error` derived from an HTTP response is raised
- **THEN** it SHALL expose `status_code`, `request_id`, `error_code`, `response_body`, and `response_headers`

### Requirement: ErrorFactory maps status and body to typed errors
The SDK SHALL provide `Nfe::ErrorFactory` with `from_response(response)` and `from_network_error(exception)`. `from_response` SHALL select the error class by status code (400/422 → `InvalidRequestError`, 401 → `AuthenticationError`, 403 → `AuthorizationError`, 404 → `NotFoundError`, 409 → `ConflictError`, 429 → `RateLimitError`, 500–599 → `ServerError`, other 4xx → `InvalidRequestError`, other ≥500 → `ServerError`). It SHALL extract `message` (from body keys `message`/`error`/`detail`/`details`/`errors`), `error_code` (from `code`/`errorCode`/`error_code`), and `request_id` (from header `x-request-id`, falling back to `x-correlation-id`). Because the extracted `message` echoes server input, the factory SHALL cap the message at a bounded length and scrub control characters before placing it on the error.

#### Scenario: Oversized server message is capped and scrubbed
- **WHEN** `from_response` receives a body whose `message` is very long or contains control characters
- **THEN** the resulting error message SHALL be truncated to a bounded length with control characters removed, so an attacker-controlled body cannot flood logs or inject terminal sequences

#### Scenario: 404 maps to NotFoundError
- **WHEN** `from_response` receives a `Response` with status 404
- **THEN** it SHALL return an `Nfe::NotFoundError` whose `status_code` is 404

#### Scenario: 422 maps to InvalidRequestError
- **WHEN** `from_response` receives a `Response` with status 422
- **THEN** it SHALL return an `Nfe::InvalidRequestError`

#### Scenario: Rate limit carries retry-after
- **WHEN** `from_response` receives status 429 with a `Retry-After: 30` header
- **THEN** it SHALL return an `Nfe::RateLimitError` whose `retry_after` is 30

#### Scenario: Message and request id extracted
- **WHEN** `from_response` receives a JSON body `{ "message": "CNPJ inválido", "code": "INVALID_CNPJ" }` with header `x-request-id: req_123`
- **THEN** the raised error SHALL have message `"CNPJ inválido"`, `error_code` `"INVALID_CNPJ"`, and `request_id` `"req_123"`

#### Scenario: Non-JSON body does not break the factory
- **WHEN** `from_response` receives a non-JSON body (e.g. HTML or plain text)
- **THEN** it SHALL still return the correct error class with a default message and SHALL NOT raise a parse error

#### Scenario: Network exception mapping
- **WHEN** `from_network_error` receives a `Net::ReadTimeout` or `Net::OpenTimeout`
- **THEN** it SHALL return an `Nfe::TimeoutError`; for `SocketError`, `Errno::ECONNREFUSED`, or `OpenSSL::SSL::SSLError` it SHALL return an `Nfe::ApiConnectionError`, preserving the original exception as cause

### Requirement: 202 responses are not auto-followed
The transport SHALL NOT follow HTTP 202 responses or any redirect automatically. The `Response` object SHALL expose the raw status code and headers (including `Location`) so the calling resource can implement the discriminated Pending/Issued contract (defined in `add-client-core`).

#### Scenario: API returns 202 with Location
- **WHEN** the transport receives HTTP 202 with `Location: /v1/companies/{id}/serviceinvoices/{invoiceId}`
- **THEN** it SHALL return a `Response` with `status == 202` and the `Location` header preserved, without fetching the resource at `Location`

### Requirement: User-Agent identification
Every outgoing request SHALL carry a `User-Agent` header in the format `NFE.io Ruby Client v<sdk-version> ruby/<ruby-version> (<platform>)`, built via `Nfe::Http::UserAgent.build`, unless the caller overrides it explicitly. The SDK version SHALL be read from `Nfe::VERSION`.

#### Scenario: Default User-Agent format
- **WHEN** `Nfe::Http::UserAgent.build` is called with `Nfe::VERSION == "1.0.0"` on Ruby 3.3
- **THEN** it SHALL return a string matching `NFE.io Ruby Client v1.0.0 ruby/3.3.0 (<platform>)`

### Requirement: API key authentication header
The SDK SHALL authenticate requests using the `X-NFE-APIKEY` header carrying the API key. The header value SHALL be the API key provided on the `Request` (resolved per host family by `Nfe::Configuration` in `add-client-core`). The transport itself SHALL remain authentication-agnostic and send whatever auth header the `Request` carries.

#### Scenario: API key header sent
- **WHEN** a `Request` is built with header `X-NFE-APIKEY` set to the configured key
- **THEN** the transport SHALL transmit that header verbatim to the wire

### Requirement: Idempotency-Key slot
The `Nfe::Http::Request` SHALL carry an optional `idempotency_key`. When present, the transport SHALL send it as the `Idempotency-Key` request header. When nil, no `Idempotency-Key` header SHALL be sent. A present key SHALL also make the request eligible for retry per `Request#idempotent?`.

#### Scenario: Idempotency key sent when present
- **WHEN** a `Request` carries `idempotency_key: "9f1c..."`
- **THEN** the transport SHALL send `Idempotency-Key: 9f1c...` and the request SHALL be retry-eligible even for `POST`

#### Scenario: No idempotency key by default
- **WHEN** a `Request` has `idempotency_key: nil`
- **THEN** the transport SHALL NOT send any `Idempotency-Key` header

### Requirement: Pluggable duck-typed logger with secret redaction
The SDK SHALL support an optional logger (a duck-typed object responding to `info`/`warn`/`error`, such as Ruby's stdlib `::Logger`), configured via `Nfe::Configuration` (in `add-client-core`). When provided, the transport layer SHALL log request start at `info`, retries at `warn`, and final failures at `error`. Before logging, it SHALL redact the values of sensitive headers — `X-NFE-APIKEY`, `Authorization`, `Idempotency-Key`, and any header whose name matches `/secret|apikey|token/i` — replacing them with `[REDACTED]`. The SDK SHALL NOT declare any logging gem as a runtime dependency.

#### Scenario: Logger provided and request fails
- **WHEN** a logger is configured and a request finally fails with HTTP 500
- **THEN** the logger SHALL receive at least one `error` entry including the method, URL, and status code, with the API key value redacted to `[REDACTED]`

#### Scenario: No logger provided
- **WHEN** no logger is configured
- **THEN** no logging SHALL occur and no logging gem SHALL be required at runtime

#### Scenario: Logging never breaks the request
- **WHEN** the configured logger itself raises while logging
- **THEN** the SDK SHALL rescue the logging error and complete the HTTP request normally

### Requirement: Request and response bodies are never logged by default
The SDK SHALL NOT log request or response BODIES by default. Default log entries SHALL be limited to the HTTP method, URL, status code, and `request_id`. Body logging SHALL be available only behind an explicit opt-in flag (`Nfe::Configuration#log_request_body`, defined in `add-client-core`); when enabled, any logged body SHALL be truncated to a bounded length and SHALL pass through redaction so that secrets and PII never appear verbatim. `Nfe::Error#response_body` SHALL remain available on raised errors for programmatic inspection, but SHALL NOT be auto-logged by the transport's default log entries.

#### Scenario: Bodies are omitted from default logs
- **WHEN** a logger is configured with no body-logging opt-in and a request carrying a CNPJ/CPF in its body fails with HTTP 422 whose response body echoes the CNPJ/CPF
- **THEN** no log line SHALL contain the request body, the response body, the CNPJ, the CPF, the API key, or the certificate password — only method, URL, status, and `request_id`

#### Scenario: Opt-in body logging is truncated and redacted
- **WHEN** `log_request_body` is explicitly enabled and a body is logged
- **THEN** the logged body SHALL be truncated to a bounded length and SHALL have sensitive values (API key, `Idempotency-Key`, secrets/tokens) redacted to `[REDACTED]`

### Requirement: Connection pool is thread-safe
The per-origin keep-alive connection pool inside `Nfe::Http::NetHttp` SHALL be guarded by a `Mutex`, so a single transport (and the `Client` that shares it) MAY be used concurrently from multiple threads without corrupting the pool or sharing a `Net::HTTP` socket across two in-flight requests. This makes a shared `Client` safe under Rails/Sidekiq/Puma multi-threaded execution.

#### Scenario: Concurrent requests share the transport safely
- **WHEN** multiple threads issue requests through the same `Nfe::Http::NetHttp` instance at the same time
- **THEN** access to the per-origin connection cache SHALL be serialized by a `Mutex` and no two threads SHALL use the same underlying socket simultaneously

### Requirement: Per-call request option overrides
The transport SHALL honor per-call overrides supplied by the resource layer via `Nfe::RequestOptions` (`Data.define` with `api_key`, `base_url`, `timeout`; defined in `add-client-core`). When a `Request` is built with such overrides, the transport SHALL use the overridden `base_url` and timeout for that single call and SHALL transmit the overridden API key in the `X-NFE-APIKEY` header, without mutating any global configuration or affecting other concurrent calls. This enables multi-tenant per-call API keys without constructing a second `Client`.

#### Scenario: Per-call base URL and timeout override
- **WHEN** a single `Request` carries an overridden `base_url` and `read_timeout` derived from `Nfe::RequestOptions`
- **THEN** the transport SHALL route that one call to the overridden `base_url` with the overridden timeout, leaving the default configuration unchanged for subsequent calls

#### Scenario: Per-call API key override
- **WHEN** a single `Request` carries an API key derived from a per-call `Nfe::RequestOptions`
- **THEN** the transport SHALL send that key in `X-NFE-APIKEY` for that call only, enabling multi-tenant usage from one shared `Client`

### Requirement: POST is not auto-retried even with an idempotency key available
The transport SHALL NOT automatically retry a `POST` request as a safety default, diverging deliberately from the Node.js and PHP SDKs (which retry POST). A `POST` becomes retry-eligible ONLY when the caller supplies an `idempotency_key` (set by the resource `create`/`create_with_state_tax` kwarg, NEVER auto-generated by the transport). This divergence SHALL be documented for integrators in the README (owned by the release-tooling change).

#### Scenario: POST without idempotency key is never auto-retried
- **WHEN** a `POST` request without an `idempotency_key` receives HTTP 503
- **THEN** the transport SHALL return the 503 response immediately without retrying, so an invoice is never re-issued automatically

#### Scenario: POST with caller-supplied idempotency key is retry-eligible
- **WHEN** a `POST` request carries a caller-supplied `idempotency_key` and receives HTTP 503
- **THEN** the request SHALL be eligible for retry (per `Request#idempotent?`), the `Idempotency-Key` header SHALL be replayed on each attempt, and the key SHALL NOT be auto-generated by the transport

### Requirement: Polling and batch helpers are not part of v1.0
The HTTP transport SHALL deliver the raw 202 + `Location` contract but SHALL NOT implement polling (`pollUntilComplete` / `create_and_wait`) nor concurrent batch helpers (`create_batch`). These are explicitly deferred; the discriminated Pending/Issued contract (in `add-client-core`) plus `Nfe::FlowStatus` terminal-state checks are sufficient for manual polling loops.

#### Scenario: No automatic polling at the transport layer
- **WHEN** the transport returns a 202 with `Location`
- **THEN** it SHALL NOT issue any follow-up GET to that `Location`; resolving the async result is the caller's responsibility

