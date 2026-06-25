# webhook-signature-verification Specification

## Purpose
TBD - created by archiving change add-entity-resources. Update Purpose after archive.
## Requirements
### Requirement: Webhook signature verification helper exists without a Client
The SDK SHALL provide `Nfe::Webhook` as a stateless module of functions (using `module_function`) that verifies NFE.io webhook signatures using only the caller-supplied payload, signature, and secret. It SHALL NOT require an instantiated `Nfe::Client`, SHALL NOT read `Nfe::Configuration`, and SHALL NOT perform any network access. This is the canonical API for signature verification; `Nfe::Resources::Webhooks#verify_signature` MAY delegate to it for Node parity.

#### Scenario: Verifying without a configured Client
- **WHEN** a webhook endpoint runs in a process that has not instantiated `Nfe::Client`
- **THEN** `Nfe::Webhook.verify_signature(payload:, signature:, secret:)` SHALL function correctly using only the provided arguments

#### Scenario: No network access
- **WHEN** any `Nfe::Webhook` method runs
- **THEN** it SHALL NOT issue any HTTP request

### Requirement: verify_signature matches the production HMAC-SHA1 scheme
`Nfe::Webhook.verify_signature(payload:, signature:, secret:) -> Boolean` SHALL return `true` only when the provided signature matches `OpenSSL::HMAC.hexdigest("SHA1", secret, payload)` computed over the raw payload bytes, after requiring and stripping the `sha1=` prefix (compared case-insensitively) and normalising the remaining hex to lower case. The comparison SHALL use `OpenSSL.secure_compare` (constant-time). The method SHALL NOT re-serialize the payload; it SHALL operate on the bytes as given.

#### Scenario: Validate a real signature from NFE.io (live fixture)
- **WHEN** the caller invokes `verify_signature` with a captured webhook body, the configured secret, and the header value `sha1=BCD17C02B9E3B40A18E745E7E04247E4AD2DD935` whose HMAC-SHA1 over the body bytes with that secret produces that digest
- **THEN** the method SHALL return `true`

#### Scenario: Uppercase hex on the wire is accepted
- **WHEN** the header value carries the digest in uppercase hex (as NFE.io sends it)
- **THEN** the method SHALL return `true` (comparison is case-insensitive)

#### Scenario: Lowercase hex is accepted
- **WHEN** the same digest is provided in lowercase hex
- **THEN** the method SHALL return `true`

#### Scenario: Round-trip of a self-computed signature
- **WHEN** the caller computes `sha1=` + `OpenSSL::HMAC.hexdigest("SHA1", secret, body)` for a random body and secret and passes it back
- **THEN** the method SHALL return `true`

#### Scenario: Constant-time comparison
- **WHEN** the method compares the received and expected digests
- **THEN** it SHALL use `OpenSSL.secure_compare` and SHALL NOT use `==`, `eql?`, or `String#==` on the hex strings

### Requirement: verify_signature rejects malformed, missing, and forged input without raising
`Nfe::Webhook.verify_signature` SHALL return `false` — and SHALL NEVER raise an exception — for any tampered body, missing input, malformed signature, wrong algorithm prefix, missing prefix, wrong length, or non-hex content.

#### Scenario: Tampered body
- **WHEN** a valid signature for body A is checked against body A mutated by one byte
- **THEN** the method SHALL return `false` and SHALL NOT raise

#### Scenario: Wrong secret
- **WHEN** the body and signature are valid for one secret but verified with a different secret
- **THEN** the method SHALL return `false`

#### Scenario: Wrong algorithm prefix (downgrade attempt)
- **WHEN** the header value is `sha256=<64 hex chars>`
- **THEN** the method SHALL return `false` and SHALL NOT raise (no implicit algorithm upgrade or downgrade)

#### Scenario: Missing prefix
- **WHEN** the header value is a bare 40-character hex string with no `sha1=` prefix
- **THEN** the method SHALL return `false` and SHALL NOT raise

#### Scenario: Wrong length
- **WHEN** the header value is `sha1=abc`
- **THEN** the method SHALL return `false` and SHALL NOT raise

#### Scenario: Non-hex content
- **WHEN** the header value is `sha1=` followed by 40 non-hex characters
- **THEN** the method SHALL return `false` and SHALL NOT raise

#### Scenario: Missing or empty secret
- **WHEN** `secret` is `nil` or an empty string
- **THEN** the method SHALL return `false` and SHALL NOT raise

#### Scenario: Missing or empty signature
- **WHEN** `signature` is `nil`, an empty string, or an empty array
- **THEN** the method SHALL return `false` and SHALL NOT raise

#### Scenario: Header delivered as an array
- **WHEN** the signature argument is a single-element array (the shape some Rack/HTTP stacks expose for repeated headers)
- **THEN** the method SHALL use the first element and verify normally

### Requirement: construct_event verifies, parses, and returns a typed event
`Nfe::Webhook.construct_event(payload:, signature:, secret:) -> Nfe::WebhookEvent` SHALL first call `verify_signature`. If verification fails it SHALL raise `Nfe::SignatureVerificationError`. Otherwise it SHALL parse the payload as JSON, unwrap the NFE.io delivery envelope, and return a `Nfe::WebhookEvent`. A payload that is not valid JSON SHALL raise `Nfe::SignatureVerificationError`.

#### Scenario: Valid signature yields a WebhookEvent
- **WHEN** `construct_event` is called with a valid signature over the body `{"action":"invoice.issued","payload":{"id":"abc","status":"Issued"}}`
- **THEN** it SHALL return a `Nfe::WebhookEvent` with `type == "invoice.issued"` and `data == {"id" => "abc", "status" => "Issued"}`

#### Scenario: Invalid signature raises
- **WHEN** `construct_event` is called with a signature that does not match the body and secret
- **THEN** it SHALL raise `Nfe::SignatureVerificationError` and SHALL NOT return an event

#### Scenario: Malformed JSON raises
- **WHEN** `construct_event` is called with a valid signature but a body that is not valid JSON
- **THEN** it SHALL raise `Nfe::SignatureVerificationError`

### Requirement: WebhookEvent is an immutable value object
The SDK SHALL provide `Nfe::WebhookEvent = Data.define(:type, :data, :id, :created_at)`. `type` is a required string; `data` is a `Hash` of payload data; `id` and `created_at` are optional (default `nil`). `construct_event` SHALL unwrap both the `{"action" => type, "payload" => data}` and `{"event" => type, "data" => data}` envelope shapes into this form.

#### Scenario: Envelope unwrapping (action/payload)
- **WHEN** the delivered body is `{"action":"invoice.issued","payload":{"id":"abc"}}`
- **THEN** `construct_event` SHALL produce a `WebhookEvent` with `type == "invoice.issued"` and `data == {"id" => "abc"}`

#### Scenario: Event is immutable
- **WHEN** a `Nfe::WebhookEvent` is created
- **THEN** it SHALL be a frozen `Data` instance whose fields cannot be mutated

### Requirement: Documentation steers callers to raw body bytes
The SDK documentation (README and RDoc/YARD on `Nfe::Webhook`) SHALL instruct callers to read the raw request body (e.g. `request.body.read` in Rack/Rails) BEFORE parsing JSON and pass those exact bytes to `verify_signature`/`construct_event`. It SHALL warn explicitly that re-serializing a parsed object (e.g. `payload.to_json`) will not match the signed bytes and will fail unpredictably.

#### Scenario: Documented example uses raw bytes
- **WHEN** a reader copies the documented webhook-verification example
- **THEN** the snippet SHALL pass the raw request body to the verifier and SHALL parse JSON only after verification succeeds, and SHALL NOT pass a re-serialized object

### Requirement: No anti-replay primitive — handlers must be idempotent and dedupe on event/invoice id
NFE.io provides no webhook anti-replay primitive: deliveries carry only the `X-Hub-Signature` HMAC-SHA1 over the body, with no timestamp and no nonce. A valid signature therefore proves authenticity but NOT freshness — a replayed delivery carries a perfectly valid signature. The SDK documentation (README and RDoc/YARD on `Nfe::Webhook`) SHALL state this explicitly and instruct consumers that webhook handlers MUST be idempotent and MUST dedupe on the event/invoice id. To support deduplication, `construct_event` SHALL surface a stable event id on `Nfe::WebhookEvent#id` when the delivery envelope carries one (e.g. the event id or the invoice id), and `nil` when absent.

#### Scenario: Documentation warns that a valid signature is not freshness
- **WHEN** a reader consults the webhook-verification documentation
- **THEN** it SHALL state that NFE.io sends no timestamp/nonce, that signature validity does not imply freshness, and that handlers MUST be idempotent and dedupe on the event/invoice id

#### Scenario: Stable event id surfaced for deduplication
- **WHEN** `construct_event` parses a delivery whose envelope carries an event id (or invoice id)
- **THEN** the returned `Nfe::WebhookEvent#id` SHALL expose that id so the consumer can dedupe replays, and SHALL be `nil` when no such id is present

### Requirement: The legacy X-NFe-Signature / SHA-256 scheme is not implemented
The SDK SHALL implement only the `X-Hub-Signature` + HMAC-SHA1 scheme. It SHALL NOT implement the legacy `X-NFe-Signature` header or HMAC-SHA256 algorithm described in the (incorrect) distribuição documentation.

#### Scenario: SHA-256 header is rejected
- **WHEN** a caller passes a signature header using the legacy `sha256=` form
- **THEN** `verify_signature` SHALL return `false` (the SHA-1 scheme is the only supported scheme)

