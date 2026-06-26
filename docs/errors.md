---
title: Tratamento de erros no SDK Ruby da NFE.io
sidebar_label: Tratamento de erros
sidebar_position: 4
description: A hierarquia Nfe::Error, a tabela de códigos HTTP por classe, padrões idiomáticos de rescue, validação client-side fail-fast, RateLimitError#retry_after e erros de rede.
---

# Tratamento de erros

Todos os erros do SDK derivam de `Nfe::Error`, então você pode capturar a
família inteira com um único `rescue Nfe::Error`. Esta página descreve a
hierarquia, os códigos HTTP mapeados, padrões de `rescue` por tipo, a validação
client-side e os erros de rede.

## A hierarquia de erros

| Classe | Código HTTP | Quando ocorre |
| --- | --- | --- |
| `Nfe::Error` | — | Base de toda a família. |
| `Nfe::AuthenticationError` | 401 | Chave de API ausente ou inválida. |
| `Nfe::AuthorizationError` | 403 | Chave válida, mas sem permissão para o recurso. |
| `Nfe::InvalidRequestError` | 400 / 422 | Requisição malformada ou reprovada na validação. |
| `Nfe::NotFoundError` | 404 | Recurso não existe. |
| `Nfe::ConflictError` | 409 | Conflito com o estado atual do recurso. |
| `Nfe::RateLimitError` | 429 | Excesso de requisições; expõe `#retry_after`. |
| `Nfe::ServerError` | 5xx | Falha no servidor da API. |
| `Nfe::ApiConnectionError` | — | Falha de rede (DNS, conexão recusada, TLS, reset). |
| `Nfe::TimeoutError` | — | Timeout de conexão/leitura (`< ApiConnectionError`). |
| `Nfe::SignatureVerificationError` | — | Assinatura de webhook reprovada. |
| `Nfe::ConfigurationError` | — | SDK mal configurado (chave ausente, `environment` inválido). |
| `Nfe::InvoiceProcessingError` | — | Resposta 202 viola o protocolo (ex.: sem header `Location`). |

:::note `TimeoutError` é subclasse de `ApiConnectionError`
Um `rescue Nfe::ApiConnectionError` também captura `Nfe::TimeoutError`. Trate o
timeout antes, se quiser distingui-lo.
:::

## Contexto carregado pelos erros HTTP

Erros derivados de uma resposta HTTP carregam contexto para diagnóstico:
`#status_code`, `#request_id`, `#error_code`, `#response_body` e
`#response_headers`.

```ruby
begin
  client.service_invoices.retrieve(company_id: "...", invoice_id: "...")
rescue Nfe::Error => e
  e.status_code   # ex.: 404
  e.request_id    # id de correlação do servidor
  e.error_code    # código de erro legível por máquina
end
```

:::tip `#to_h` é seguro para logs
`Nfe::Error#to_h` devolve um Hash com `type`, `message`, `status_code`,
`request_id` e `error_code` — e **omite deliberadamente** o corpo e os headers
brutos, que podem conter a chave de API ou PII. Prefira-o ao logar erros.
:::

## Padrões de `rescue` por tipo

Capture do mais específico para o mais genérico:

```ruby
begin
  client.service_invoices.create(company_id: company_id, data: payload)
rescue Nfe::AuthenticationError
  # 401 — revise a chave de API.
  raise
rescue Nfe::AuthorizationError
  # 403 — a chave não tem permissão para este recurso.
  raise
rescue Nfe::InvalidRequestError => e
  # 400/422 — corrija o payload; e.message traz o detalhe do servidor.
  warn "Requisição inválida: #{e.message}"
rescue Nfe::RateLimitError => e
  # 429 — respeite o retry_after antes de tentar de novo.
  sleep(e.retry_after || 5)
  retry
rescue Nfe::ServerError
  # 5xx — falha do lado do servidor; reportar/retentar com backoff.
  raise
rescue Nfe::TimeoutError
  # Timeout de conexão/leitura.
  raise
rescue Nfe::ApiConnectionError
  # Outras falhas de rede.
  raise
rescue Nfe::Error => e
  # Rede de segurança para qualquer erro do SDK.
  warn e.to_h.inspect
  raise
end
```

## Validação client-side (fail-fast)

Validações client-side (id de empresa vazio, chave de acesso com tamanho
errado, CNPJ/CPF/CEP/UF inválidos) levantam `Nfe::InvalidRequestError` com uma
mensagem em pt-BR **antes** de qualquer requisição HTTP:

```ruby
begin
  client.service_invoices.retrieve(company_id: "", invoice_id: "abc")
rescue Nfe::InvalidRequestError => e
  # Levantado de forma síncrona, sem rede. e.status_code é nil aqui.
  warn e.message   # mensagem em português identificando o argumento inválido
end
```

:::note Sem `status_code` na validação local
Por não vir de uma resposta HTTP, um `InvalidRequestError` client-side tem
`status_code` igual a `nil` — diferente do mesmo erro vindo de um 400/422.
:::

## `RateLimitError#retry_after`

No HTTP 429, o SDK lê o header `Retry-After` (quando presente) e o expõe como um
inteiro de segundos em `#retry_after`. Pode ser `nil` se o servidor não anunciar.

```ruby
begin
  client.addresses.retrieve(postal_code: "01310100")
rescue Nfe::RateLimitError => e
  wait = e.retry_after || 5
  sleep wait
  retry
end
```

## Erros de rede

Quando nenhuma troca HTTP se completa, o SDK levanta um erro de rede em vez de
devolver uma resposta:

- `Nfe::ApiConnectionError` — DNS, conexão recusada, TLS, reset de conexão.
- `Nfe::TimeoutError` — timeout de conexão ou de leitura; subclasse de
  `ApiConnectionError`. A exceção original fica preservada em `cause`.

```ruby
begin
  client.companies.list
rescue Nfe::TimeoutError => e
  warn "Timeout: #{e.message}; causa original: #{e.cause&.class}"
rescue Nfe::ApiConnectionError => e
  warn "Falha de conexão: #{e.message}"
end
```

## Próximos passos

- [Emissão assíncrona e polling](./async-and-polling.md) — trate falhas no loop.
- [Configuração](./configuration.md) — `timeout`, `max_retries` e TLS.
- [Primeiros passos](./getting-started.md) — visão geral do SDK.
