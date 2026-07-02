# Erros, retries, idempotência, multi-tenant e webhooks

## Hierarquia de erros

Toda exceção do SDK deriva de `Nfe::Error`. Um `rescue Nfe::Error` pega tudo.

```
Nfe::Error
├─ Nfe::AuthenticationError        # 401
├─ Nfe::AuthorizationError         # 403
├─ Nfe::InvalidRequestError        # 400/422 (+ validações client-side)
├─ Nfe::NotFoundError              # 404
├─ Nfe::ConflictError              # 409
├─ Nfe::RateLimitError             # 429   (#retry_after)
├─ Nfe::ServerError                # 5xx
├─ Nfe::ApiConnectionError         # falha de rede
│  └─ Nfe::TimeoutError            # timeout (subclasse!)
├─ Nfe::SignatureVerificationError # webhook
├─ Nfe::ConfigurationError         # mal-configurado (antes do HTTP)
└─ Nfe::InvoiceProcessingError     # 202 sem Location utilizável
```

> NÃO existem `ConnectionError`, `ValidationError`, `PollingTimeoutError`.
> `TimeoutError < ApiConnectionError`, então `rescue Nfe::ApiConnectionError`
> também captura timeouts.

Cada erro de resposta carrega: `#status_code`, `#request_id`, `#error_code`,
`#response_body`, `#response_headers`. Use `#to_h` para logar com segurança —
ele **omite** body e headers (que podem ter chave de API / senha / PII).

```ruby
begin
  client.product_invoices.create(company_id: id, data: payload)
rescue Nfe::AuthenticationError, Nfe::AuthorizationError => e
  logger.error(e.to_h); raise           # chave errada/sem permissão — não re-tentar
rescue Nfe::RateLimitError => e
  sleep(e.retry_after || 5); retry
rescue Nfe::InvalidRequestError => e
  logger.warn(e.to_h)                   # payload inválido — corrija, não re-tente
rescue Nfe::TimeoutError => e
  retry_with_same_idempotency_key       # ver abaixo
rescue Nfe::Error => e
  report(e.to_h); raise
end
```

## Retries

O SDK já re-tenta no transporte (`max_retries`, padrão 3, com backoff +
jitter) para falhas transitórias. Configure no construtor:

```ruby
Nfe::Client.new(api_key: key, max_retries: 5, timeout: 30)
```

> Emissões de nota não são re-tentadas cegamente — use `idempotency_key` para
> reenviar com segurança.

## Idempotência

`idempotency_key:` (nas emissões) vira o header `Idempotency-Key`. Como o SDK
**não** re-tenta emissões automaticamente, reenviar com a **mesma** chave após um
timeout deixa o servidor deduplicar (não emite duas notas).

```ruby
key = SecureRandom.uuid
begin
  client.service_invoices.create(company_id: id, data: payload, idempotency_key: key)
rescue Nfe::TimeoutError
  client.service_invoices.create(company_id: id, data: payload, idempotency_key: key)  # mesma chave
end
```

## Multi-tenant (`request_options`)

`Nfe::RequestOptions` faz override **por chamada** sem mutar (nem reconstruir) o
`Client`. Campos nil caem na resolução normal por família.

```ruby
opts = Nfe::RequestOptions.new(api_key: tenant_api_key)  # ou base_url:, timeout:
client.service_invoices.create(company_id: id, data: payload, request_options: opts)
```

Útil para um único `Client` compartilhado (thread-safe) atendendo vários tenants
com chaves distintas.

## TLS

`ca_file`/`ca_path` (em `Nfe::Configuration`) só **adicionam** uma CA ao trust
store. Não há API para desabilitar verificação de peer (sem `VERIFY_NONE`, sem
`insecure_ssl`). O `insecureSsl` da API é propriedade do *alvo de entrega de
webhook* no servidor, não do TLS de saída do SDK.

## Webhooks — verificação e handler idempotente

```ruby
require "nfe"

def handle_webhook(request)   # ex.: Rack/Rails
  raw    = request.body.read                          # bytes BRUTOS (antes de parsear)
  sig    = request.get_header("HTTP_X_HUB_SIGNATURE") # header X-Hub-Signature
  secret = ENV.fetch("NFE_WEBHOOK_SECRET")

  unless Nfe::Webhook.verify_signature(payload: raw, signature: sig, secret: secret)
    return [401, {}, ["assinatura inválida"]]
  end

  event = Nfe::Webhook.construct_event(payload: raw, signature: sig, secret: secret)
  # event => Nfe::WebhookEvent(type:, data:, id:, created_at:)

  return [200, {}, ["duplicado"]] if already_processed?(event.id)  # DEDUPE obrigatório
  process!(event)
  mark_processed(event.id)
  [200, {}, ["ok"]]
end
```

Pontos-chave:

- **HMAC-SHA1** sobre os **bytes brutos**; header `X-Hub-Signature` (`sha1=`),
  comparação timing-safe e case-insensitive.
- `verify_signature` **nunca levanta** (retorna `false` p/ entrada inválida,
  algoritmo errado `sha256=`, tamanho/hex errado, secret vazio).
  `construct_event` levanta `Nfe::SignatureVerificationError` se assinatura/JSON
  falhar.
- Nunca re-serialize o objeto (`payload.to_json`) — bytes diferem dos assinados.
- **Validade ≠ frescor:** não há timestamp/nonce anti-replay. Assinatura válida
  prova autenticidade, **não** frescor → handler DEVE ser **idempotente** e
  **deduplicar** por `event.id` (ou id da nota).
- Eventos disponíveis (`client.webhooks.get_available_events`): `invoice.issued`,
  `invoice.cancelled`, `invoice.failed`, `invoice.processing`, `company.created`,
  `company.updated`, `company.deleted`.
- Esquema legado `X-NFe-Signature`/SHA-256/Base64 **não** é suportado.

## Concorrência

Um `Nfe::Client` é seguro para compartilhar entre threads (Puma/Sidekiq): os
acessores de recurso e transportes são memoizados sob `Mutex`. Crie um por
processo e reutilize.
