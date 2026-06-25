# add-entity-resources

## Why

Os recursos de **entidade** são pré-requisito para qualquer integração funcional com a NFE.io: sem `company` cadastrada não se emite invoice; sem certificado digital A1 (.pfx/.p12) carregado a company não emite NF-e/NFS-e/NFC-e; sem `legal_person`/`natural_person` cadastrados o relacionamento tomador/destinatário fica manual; sem `webhook` registrado o integrador não recebe notificação de mudança de `FlowStatus`. Esta change implementa os 4 recursos de entidade que rodam no host principal (`api.nfe.io`) sobre o `Nfe::Client` e o `AbstractResource` entregues em **add-client-core**.

Inclui também a **primeira camada de segurança servidor→cliente do SDK**: a verificação de assinatura HMAC dos webhooks. A NFE.io assina cada entrega com `HMAC-SHA1(secret, bytes_crus_do_corpo)`, hex em maiúsculas, prefixado com `sha1=`, no cabeçalho `X-Hub-Signature`. Isso é o **único** mecanismo que impede entregas forjadas no endpoint do consumidor (o allowlist de IP é só checagem secundária). O esquema foi confirmado por probe ao vivo contra `https://api.nfse.io/v2/webhooks` (registro `fix-webhook-signature-verification` do `client-nodejs`) e pela documentação fonte-de-verdade (`docs/documentacao/webhooks/duvidas-frequentes.md`, `ips-de-origem.md`). Por ser uma capability crítica e independente do `Client`, ela é especificada **em um spec.md separado** (`webhook-signature-verification`).

Esta change depende de **add-client-core** (consome `Nfe::Client`, `Nfe::Configuration` com o host map, `Nfe::Resources::AbstractResource`, `Nfe::ListResponse`, helpers de validação de ID e as exceções tipadas).

> ⚠️ **Atenção a defeitos conhecidos na documentação fonte** (NÃO replicar): os docs de distribuição (`distribuicao/02-doc-tecnica-clientes-dev.md` e `04-...-inbound-webhook.md`) descrevem o esquema ANTIGO e INCORRETO `X-NFe-Signature` + HMAC-SHA256. A produção usa `X-Hub-Signature` + HMAC-SHA1. O SDK Node atual também tem esse bug (corrigido na change `fix-webhook-signature-verification`). O Ruby **nasce certo**.

## What Changes (high-level)

### Recursos implementados (4)

| Recurso (acessor snake_case) | Host base | Operações principais |
|---|---|---|
| `companies` | `api.nfe.io` | create, list, list_all, list_each, retrieve, update, remove, find_by_tax_number, find_by_name, get_companies_with_certificates, get_companies_with_expiring_certificates, **upload_certificate, replace_certificate, validate_certificate (local OpenSSL::PKCS12)**, get_certificate_status, check_certificate_expiration |
| `legal_people` | `api.nfe.io` | list, create, retrieve, update, delete, create_batch, find_by_tax_number |
| `natural_people` | `api.nfe.io` | list, create, retrieve, update, delete, create_batch, find_by_tax_number |
| `webhooks` | `api.nfe.io` | list, create, retrieve, update, delete, test, get_available_events |

> Host base = `base_url_for(:main)` → `https://api.nfe.io`; o segmento `/v1` é fornecido pelo `api_version` do recurso (URL efetiva `https://api.nfe.io/v1/...`).

### Diferença de escopo vs SDK PHP: upload de certificado **INCLUÍDO** no v1 Ruby

O SDK PHP v3.0 **diferiu** upload/replace/validate de certificado por não ter multipart no `CurlTransport`. O Ruby v1 **inclui** essas operações desde a primeira release porque:
- `Net::HTTP` (stdlib, já é nossa dependência única de runtime) suporta multipart/form-data nativamente via `set_form` / `Net::HTTP::Post#set_form`, sem nenhuma gem extra.
- `OpenSSL::PKCS12` (stdlib) faz parse **real** do .pfx/.p12 e valida a senha (levanta `OpenSSL::PKCS12::PKCS12Error` em senha errada) — muito mais forte que a checagem de magic-byte `0x3082` do validador do Node, que é raso e fabrica metadata. Extraímos `subject`, `issuer`, `not_before`, `not_after` e calculamos `days_until_expiration` de verdade.

### Adicionado (suporte)

- **`Nfe::Webhook`** (módulo de funções, sem dependência de `Client`):
  - `Nfe::Webhook.verify_signature(payload:, signature:, secret:)` — verificação low-level; retorna `Boolean`; nunca levanta exceção. HMAC-SHA1 sobre bytes crus, prefixo `sha1=`, hex case-insensitive, comparação constante via `OpenSSL.secure_compare`.
  - `Nfe::Webhook.construct_event(payload:, signature:, secret:)` — high-level: verifica + parseia JSON + retorna `Nfe::WebhookEvent`; levanta `Nfe::SignatureVerificationError` em assinatura inválida (estilo `Stripe::Webhook.construct_event`).
- **`Nfe::WebhookEvent`** — `Data.define(:type, :data, :id, :created_at)` imutável; desempacota o envelope de entrega (`{"action" => ..., "payload" => ...}` ou `{"event" => ..., "data" => ...}`) para a forma canônica.
- **`Nfe::CertificateInfo`** — `Data.define(:subject, :issuer, :not_before, :not_after, :serial_number)` retornado por `validate_certificate`.
- **`Nfe::CertificateStatus`** — `Data.define(:has_certificate, :expires_on, :valid, :days_until_expiration, :expiring_soon, :details)` retornado por `get_certificate_status` (campos `days_until_expiration`/`expiring_soon` computados client-side a partir de `expires_on`).
- Desempacotamento de envelopes descobertos: `companies`/`legal_people`/`natural_people` retornam `{"<plural>" => ...}` na maioria dos endpoints; cada recurso desembrulha a chave correta antes de hidratar o `Data.define`.

### Não inclui (deferido para fora deste change)

- **Iterador auto-paginador "streaming"** equivalente ao `listIterator` (async generator) do Node — o Ruby idiomático oferece `list_each` (um `Enumerator` que pagina sob demanda via `Enumerator.new`/`yield`); um `Enumerator::Lazy` mais sofisticado fica para release futura.
- **`create_and_wait` / `create_batch` concorrente nos invoice resources** — fora do escopo desta change (pertence a add-invoice-resources). `create_batch` em `legal_people`/`natural_people` aqui é um loop **sequencial** (sem concorrência).
- **Validação de dígito verificador de CNPJ/CPF no `companies.create`** — o Node valida check-digit client-side, mas isso colide com o **CNPJ alfanumérico** (IN RFB 2.229/2024, vigente a partir de julho/2026) que admite letras nas 12 primeiras posições. O Ruby v1 valida apenas formato/comprimento e **não coage para Integer**, deixando o check-digit para o servidor — evitando a armadilha do `validateCNPJ` numérico-only do Node.

## Capabilities

### New Capabilities
- `entity-resources`: os 4 recursos de entidade (companies + certificado, legal_people, natural_people, webhooks) + DTOs `Data.define` de suporte (`CertificateInfo`, `CertificateStatus`, `WebhookEvent`).
- `webhook-signature-verification`: o módulo `Nfe::Webhook` (`verify_signature` + `construct_event`) com o esquema HMAC-SHA1/`X-Hub-Signature` validado em produção.

### Modified Capabilities
- nenhuma — esta change apenas **consome** `add-client-core` (host map, `AbstractResource`, contrato 202, exceções) sem modificar a sua spec.

## Impact

- **Affected code**: `lib/nfe/resources/companies.rb`, `legal_people.rb`, `natural_people.rb`, `webhooks.rb`; `lib/nfe/webhook.rb`; `lib/nfe/webhook_event.rb`; `lib/nfe/certificate.rb` (validador OpenSSL + `CertificateInfo`/`CertificateStatus`). Assinaturas em `sig/nfe/resources/*.rbs`, `sig/nfe/webhook.rbs`, `sig/nfe/certificate.rbs`. Testes em `spec/nfe/resources/*_spec.rb`, `spec/nfe/webhook_spec.rb`, `spec/nfe/certificate_spec.rb`.
- **Spec impact**: adiciona as capabilities `entity-resources` e `webhook-signature-verification`. Consome `client-core` (host map family `main`, `AbstractResource`, exceções) sem modificá-la.
- **Dependencies**: depende de **add-client-core** (que por sua vez depende de add-http-transport e add-ruby-foundation). Compartilha os helpers de validação de ID/CNPJ/CPF e o `Nfe::ListResponse` definidos lá.
- **Riscos**:
  - Envelopes de resposta (`{"companies" => {...}}`, `{"legalPeople" => [...]}`) precisam ser desembrulhados corretamente por método; um envelope inconsistente entre endpoints quebra a hidratação — coberto por fixtures de teste.
  - `find_by_tax_number`/`find_by_name` fazem `list_all` + filtro client-side; em contas grandes (>50 entidades) é ineficiente — documentado como conveniência, não otimizado.
  - `upload_certificate` depende de o `Net::HTTP` transport (de add-http-transport) expor um caminho multipart; se o transport só aceitar `String` body, esta change precisa coordenar com add-http-transport — registrado em design.md (D3) e tasks.
  - O endpoint exato de `webhooks.test` (`/test` vs `/pings/test`) diverge entre specs OpenAPI — smoke test em sandbox antes do GA.
