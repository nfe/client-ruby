# Tasks — add-entity-resources

> Depende de **add-client-core** (consome `Nfe::Client`, `Nfe::Configuration` com host map, `Nfe::Resources::AbstractResource`, `Nfe::ListResponse`, helpers de validação de ID/CNPJ/CPF e as exceções tipadas). Todo arquivo `.rb` começa com `# frozen_string_literal: true`.
>
> **Status (2026-06-25): IMPLEMENTADO e verificado verde via Docker na matrix Ruby 3.2/3.3/3.4.** Entregue: `Nfe::Webhook` (verify_signature HMAC-SHA1 nunca-levanta + construct_event) + `Nfe::WebhookEvent`; `Nfe::CertificateValidator`/`CertificateInfo`/`CertificateStatus` (OpenSSL::PKCS12); DTOs hand-written `Nfe::Company`/`LegalPerson`/`NaturalPerson`/`WebhookSubscription` (com `from_api`); `AbstractResource#upload_multipart`/`unwrap`; e os 4 recursos `Companies` (CRUD + certificado + multipart + finders), `LegalPeople`, `NaturalPeople`, `Webhooks` (CRUD + test + get_available_events + verify_signature). Gate: rspec 404/0 (cobertura ~95.9%), rubocop 0, steep 0, rbs ok, generate:check in-sync. Nota: o DTO de webhook é `Nfe::WebhookSubscription` (o constante `Nfe::Webhook` é o módulo de verificação). `get_*` mantêm o nome (paridade Node; `Naming/AccessorMethodName` desabilitado).

## 1. Verificação de assinatura: `Nfe::Webhook` + `Nfe::WebhookEvent`

- [ ] 1.1 Criar `lib/nfe/webhook_event.rb` — `Nfe::WebhookEvent = Data.define(:type, :data, :id, :created_at)`. Construtor por keyword (Data.define já é keyword/positional). `data` é `Hash`; `id`/`created_at` opcionais (default `nil`).
- [ ] 1.2 Criar `lib/nfe/webhook.rb` — `module Nfe::Webhook` com `module_function`:
  - `verify_signature(payload:, signature:, secret:) -> bool` — implementa os 6 passos de design D3 (guarda de nil/vazio → normaliza header Array→[0] → exige/strip prefixo `sha1=` case-insensitive, recusa `sha256=` → `downcase` + valida `/\A[a-f0-9]{40}\z/` → `OpenSSL::HMAC.hexdigest("SHA1", secret, payload)` sobre bytes crus → `OpenSSL.secure_compare`). **Nunca levanta.**
  - `construct_event(payload:, signature:, secret:) -> Nfe::WebhookEvent` — chama `verify_signature`; se `false`, levanta `Nfe::SignatureVerificationError`; senão `JSON.parse(payload)` (em `JSON::ParserError`, levanta `Nfe::SignatureVerificationError` com mensagem de payload malformado) e desembrulha o envelope (`action`/`payload` ou `event`/`data`) em `WebhookEvent`.
  - Constante privada `SIGNATURE_PREFIX = "sha1="` e `HEX_RE = /\A[a-f0-9]{40}\z/`.
- [ ] 1.3 Garantir `require "openssl"`, `require "json"` no topo (stdlib; sem gem).
- [ ] 1.4 Expor delegação de instância para paridade Node: em `lib/nfe/resources/webhooks.rb`, método `verify_signature(payload:, signature:, secret:)` que delega a `Nfe::Webhook.verify_signature` (a API canônica é o módulo estático).
- [ ] 1.5 `sig/nfe/webhook.rbs` e `sig/nfe/webhook_event.rbs` — assinaturas RBS (`def self.verify_signature: (payload: String, signature: String?, secret: String?) -> bool`, etc.).
- [ ] 1.6 Tests `spec/nfe/webhook_spec.rb` — matriz completa (vide spec `webhook-signature-verification`): fixture real do probe (`sha1=BCD17C02B9E3B40A18E745E7E04247E4AD2DD935`-style), hex maiúsculo e minúsculo, round-trip aleatório, corpo adulterado, prefixo errado `sha256=`, sem prefixo, comprimento errado `sha1=abc`, não-hex, secret vazio/nil, signature nil/vazia/array, envelope `action`/`payload`, JSON malformado, "nunca levanta" em cada caso negativo (`expect { ... }.not_to raise_error`).

## 2. Suporte de transporte: multipart para upload de certificado (coordenação com add-http-transport)

- [ ] 2.1 Confirmar/garantir que o transport `Net::HTTP` de add-http-transport aceita corpo multipart. Se aceitar só `String`, adicionar caminho mínimo: `AbstractResource#upload_multipart(path, parts)` que monta `Net::HTTP::Post#set_form(parts, "multipart/form-data")` e usa o mesmo pipeline de auth/erro/host do GET/POST normais.
- [ ] 2.2 `AbstractResource#download(path, accept:) -> String` — GET com `Accept` específico retornando `response.body` cru com `force_encoding(Encoding::ASCII_8BIT)` (mesmo que estes recursos quase não baixem binário, mantém a interface consistente; reusa o helper de add-client-core se já existir).
- [ ] 2.3 Helper de desembrulho: `AbstractResource#unwrap(payload, key) -> Hash/Array` — retorna `payload[key]` se presente, senão `payload` (tolerante a envelope ausente). Reusa de add-client-core se já existir.

## 3. Validador de certificado: `OpenSSL::PKCS12` + DTOs

- [ ] 3.1 Criar `lib/nfe/certificate.rb` com:
  - `Nfe::CertificateInfo = Data.define(:subject, :issuer, :not_before, :not_after, :serial_number)`.
  - `Nfe::CertificateStatus = Data.define(:has_certificate, :expires_on, :valid, :days_until_expiration, :expiring_soon, :details)`.
  - `module Nfe::CertificateValidator` (`module_function`): `supported_format?(filename) -> bool` (extensão `.pfx`/`.p12`, case-insensitive); `validate(der_bytes, password) -> Nfe::CertificateInfo` (faz `OpenSSL::PKCS12.new(der_bytes, password)`, captura `OpenSSL::PKCS12::PKCS12Error` → levanta `Nfe::InvalidRequestError` "Certificado ou senha inválidos"; extrai subject/issuer/not_before/not_after/serial); `days_until_expiration(not_after) -> Integer`; `expiring_soon?(not_after, threshold_days = 30) -> bool`.
- [ ] 3.2 `require "openssl"` no topo.
- [ ] 3.3 `sig/nfe/certificate.rbs` — assinaturas RBS dos `Data.define` e do `CertificateValidator`.
- [ ] 3.4 Tests `spec/nfe/certificate_spec.rb` — fixture .pfx de teste (gerado no setup via `OpenSSL::PKCS12.create`): senha correta extrai metadata real; senha errada levanta `Nfe::InvalidRequestError`; bytes inválidos (não-DER) levanta `Nfe::InvalidRequestError`; `supported_format?` para `.pfx`/`.p12`/`.PFX` true e `.pem`/`.txt` false; `days_until_expiration`/`expiring_soon?` com datas conhecidas.

## 4. `CompaniesResource`

- [ ] 4.1 Criar `lib/nfe/resources/companies.rb` — `Nfe::Resources::Companies < Nfe::Resources::AbstractResource`; `api_family` → `:main`; `api_version` → `"v1"`.
- [ ] 4.2 `create(data) -> Company` — POST `/companies`; valida formato de `federalTaxNumber` (11/14 dígitos, sem coagir para Integer, sem check-digit — design D12) e formato de e-mail se presente; desembrulha envelope `companies`; hidrata `Nfe::Company`.
- [ ] 4.3 `list(page_index: 0, page_count: 100) -> Nfe::ListResponse` — GET `/companies`; converte `page` 1-based da API para `page_index` 0-based.
- [ ] 4.4 `list_all -> Array[Company]` — pagina com `page_count: 100` até a página vir com < 100 itens.
- [ ] 4.5 `list_each -> Enumerator` (ou bloco) — `Enumerator.new` que pagina sob demanda e `yield`-a cada company (substituto idiomático do `listIterator` async do Node).
- [ ] 4.6 `retrieve(company_id) -> Company` — GET `/companies/{id}`; desembrulha `companies`; valida `company_id` antes; 404 → `Nfe::NotFoundError`.
- [ ] 4.7 `update(company_id, data) -> Company` — PUT `/companies/{id}`; valida dados; desembrulha.
- [ ] 4.8 `remove(company_id) -> Hash` — DELETE; retorna `{ deleted: bool, id: String }` (nome `remove` para evitar conflito com semântica de `delete`; paridade Node/PHP).
- [ ] 4.9 `find_by_tax_number(tax_number) -> Company?` — normaliza para dígitos, valida 11/14, `list_all` + filtro client-side; `nil` se não achar.
- [ ] 4.10 `find_by_name(name) -> Array[Company]` — `list_all` + `String#downcase.include?` case-insensitive; levanta `Nfe::InvalidRequestError` se nome vazio.
- [ ] 4.11 `validate_certificate(file:, password:) -> Nfe::CertificateInfo` — local-only; lê bytes (caminho de arquivo ou String binária) e delega a `Nfe::CertificateValidator.validate`. **Sem HTTP.**
- [ ] 4.12 `upload_certificate(company_id, file:, password:, filename: nil) -> Hash` — pré-valida `supported_format?` (se filename dado) + roda `validate_certificate` (fail-fast); monta multipart (`file` + `password`, nome de campo `file` conforme spec OpenAPI v1/v2) via `upload_multipart`; POST `/companies/{id}/certificate`; retorna `{ uploaded: bool, message: String? }`.
- [ ] 4.13 `replace_certificate(company_id, file:, password:, filename: nil) -> Hash` — alias de `upload_certificate` (a API trata a substituição).
- [ ] 4.14 `get_certificate_status(company_id) -> Nfe::CertificateStatus` — GET `/companies/{id}/certificate`; computa `days_until_expiration` e `expiring_soon` client-side a partir de `expires_on` (quando `has_certificate && expires_on`).
- [ ] 4.15 `check_certificate_expiration(company_id, threshold_days: 30) -> Hash?` — reusa `get_certificate_status`; retorna `{ expiring: true, days_remaining:, expires_on: }` se `0 <= days_remaining < threshold_days`, senão `nil`.
- [ ] 4.16 `get_companies_with_certificates -> Array[Company]` — `list_all` + N `get_certificate_status` (pula company que falhar); inclui as com `has_certificate && valid`.
- [ ] 4.17 `get_companies_with_expiring_certificates(threshold_days: 30) -> Array[Company]` — `list_all` + N `check_certificate_expiration`.
- [ ] 4.18 Validação de `company_id` via helper de add-client-core no início de cada método com ID.
- [ ] 4.19 `sig/nfe/resources/companies.rbs` — assinaturas RBS de todos os métodos públicos.
- [ ] 4.20 Tests `spec/nfe/resources/companies_spec.rb` (transport mockado): CRUD + envelope unwrap + `list` 1-based→0-based + `list_all` multi-página + `find_by_*` + cert status com threshold + `upload_certificate` multipart (assert campos `file`/`password` e path) + `validate_certificate` com .pfx fixture + `remove` retorna `{ deleted:, id: }` + 404 → `Nfe::NotFoundError` + `company_id` vazio → `Nfe::InvalidRequestError` sem HTTP.

## 5. `LegalPeopleResource`

- [ ] 5.1 Criar `lib/nfe/resources/legal_people.rb` — `< Nfe::Resources::AbstractResource`; `api_family :main`; `api_version "v1"`.
- [ ] 5.2 `list(company_id) -> Nfe::ListResponse` — GET `/companies/{id}/legalpeople`; desembrulha `{"legalPeople" => [...]}` (sem parâmetros de paginação, paridade Node).
- [ ] 5.3 `create(company_id, data) -> LegalPerson` — POST; desembrulha `{"legalPeople" => {...}}`.
- [ ] 5.4 `retrieve(company_id, legal_person_id) -> LegalPerson` — GET por ID; desembrulha.
- [ ] 5.5 `update(company_id, legal_person_id, data) -> LegalPerson` — PUT; desembrulha.
- [ ] 5.6 `delete(company_id, legal_person_id) -> nil` — DELETE.
- [ ] 5.7 `create_batch(company_id, list) -> Array[LegalPerson]` — loop **sequencial** sobre `create`; RDoc avisa "diferente do Node (Promise.all), é sequencial".
- [ ] 5.8 `find_by_tax_number(company_id, federal_tax_number) -> LegalPerson?` — `list` + filtro por `federal_tax_number` (CNPJ, normaliza para dígitos).
- [ ] 5.9 Validação de IDs antes de cada chamada.
- [ ] 5.10 `sig/nfe/resources/legal_people.rbs`.
- [ ] 5.11 Tests `spec/nfe/resources/legal_people_spec.rb` — CRUD + envelope `legalPeople` + create_batch sequencial + find_by_tax_number + ID inválido sem HTTP.

## 6. `NaturalPeopleResource`

- [ ] 6.1 Criar `lib/nfe/resources/natural_people.rb` — paralela a legal_people; `api_family :main`; `api_version "v1"`.
- [ ] 6.2 `list / create / retrieve / update / delete / create_batch / find_by_tax_number` com endpoint `/companies/{id}/naturalpeople` e envelope `{"naturalPeople" => ...}`.
- [ ] 6.3 `find_by_tax_number` normaliza CPF para 11 dígitos antes de filtrar.
- [ ] 6.4 Validação de IDs antes de cada chamada.
- [ ] 6.5 `sig/nfe/resources/natural_people.rbs`.
- [ ] 6.6 Tests `spec/nfe/resources/natural_people_spec.rb` — paralela a legal_people, com envelope `naturalPeople` e normalização CPF.

## 7. `WebhooksResource`

- [ ] 7.1 Criar `lib/nfe/resources/webhooks.rb` — `< Nfe::Resources::AbstractResource`; `api_family :main`; `api_version "v1"`.
- [ ] 7.2 `list(company_id) -> Nfe::ListResponse` — GET `/companies/{id}/webhooks` (company-scoped).
- [ ] 7.3 `create(company_id, data) -> Webhook` — POST; aceita `url`, `events`, `secret`, `active`.
- [ ] 7.4 `retrieve(company_id, webhook_id) -> Webhook` — GET por ID.
- [ ] 7.5 `update(company_id, webhook_id, data) -> Webhook` — PUT.
- [ ] 7.6 `delete(company_id, webhook_id) -> nil` — DELETE.
- [ ] 7.7 `test(company_id, webhook_id) -> Hash` — POST `/test`; retorna `{ success:, message: }`. (Confirmar path `/test` vs `/pings/test` em smoke.)
- [ ] 7.8 `get_available_events -> Array[String]` — lista estática hard-coded dos 7 eventos (design D10).
- [ ] 7.9 `verify_signature(payload:, signature:, secret:) -> bool` — delega a `Nfe::Webhook.verify_signature` (paridade Node; a API canônica é o módulo).
- [ ] 7.10 Validação de IDs antes de cada chamada.
- [ ] 7.11 `sig/nfe/resources/webhooks.rbs`.
- [ ] 7.12 Tests `spec/nfe/resources/webhooks_spec.rb` — CRUD + `test` + `get_available_events` (7 eventos exatos) + `verify_signature` delegando ao módulo.

## 8. Hidratação de DTOs (Data.define)

- [ ] 8.1 Confirmar que `Nfe::Company`, `Nfe::LegalPerson`, `Nfe::NaturalPerson`, `Nfe::Webhook` existem como `Data.define` gerados (de OpenAPI) sob `lib/nfe/generated/` OU criar DTOs hand-written sob `lib/nfe/resources/dto/` se o gerador não cobrir o shape de resposta (não editar arquivos gerados).
- [ ] 8.2 Cada recurso hidrata o `Data.define` correto a partir do payload desembrulhado, tolerando chaves ausentes (campos opcionais → `nil`).
- [ ] 8.3 `sig/` para quaisquer DTOs hand-written criados.

## 9. Integração com `Nfe::Client`

- [ ] 9.1 Confirmar que os acessores lazy snake_case `client.companies`, `client.legal_people`, `client.natural_people`, `client.webhooks` (de add-client-core) instanciam os recursos desta change com o HTTP client do host `main`.
- [ ] 9.2 Tests de integração leve em `spec/nfe/client_spec.rb` (ou no spec de cada recurso) confirmando que cada acessor devolve uma instância funcional (não stub) e roteia para a URL efetiva `https://api.nfe.io/v1/...` (host `https://api.nfe.io` de `base_url_for(:main)` + `/v1` do `api_version`).

## 10. Documentação

- [ ] 10.1 README — tabela de recursos com os 4 acessores de entidade e um exemplo 1-linha de cada.
- [ ] 10.2 README — seção "Verificação de assinatura de webhook" com exemplo Rack/Rails que lê `request.body.read` (bytes crus) ANTES do parse e bloco de aviso "não use `payload.to_json`".
- [ ] 10.3 README — seção "Certificado digital" com exemplo de `upload_certificate` e `validate_certificate` (OpenSSL::PKCS12 real).
- [ ] 10.4 RDoc/YARD em cada método público (paridade com o JSDoc do Node; pt-BR onde fizer sentido), marcando `find_by_*`/`get_companies_with_*` como "conveniência, não otimizado".

## 11. Validação end-to-end

- [x] 11.1 `bundle exec rspec` verde — 404 exemplos / 0 falhas, cobertura ~95.9% (docker 3.2/3.3/3.4); matriz completa de `Nfe::Webhook.verify_signature`.
- [x] 11.2 `bundle exec steep check` — 0 erros (docker 3.2/3.3/3.4).
- [x] 11.3 `bundle exec rubocop` — 0 offenses; `# frozen_string_literal: true` em todo `.rb`.
- [x] 11.4 `openspec validate add-entity-resources --strict` passa (ambas as capabilities).

## 12. Smoke test manual (opt-in, fora do CI)

- [ ] 12.1 Sandbox: create/list/retrieve/update/remove de company.
- [ ] 12.2 `upload_certificate` com um .pfx real → `get_certificate_status` retorna `expires_on` e `days_until_expiration` corretos.
- [ ] 12.3 Criar webhook → `test()` → confirmar entrega em webhook.site (confirmar path `/test`).
- [ ] 12.4 Receber payload real → `Nfe::Webhook.construct_event` → conferir `WebhookEvent` (assinatura válida) e `Nfe::SignatureVerificationError` (assinatura forjada).
- [ ] 12.5 Registrar resultados em `.notes/entity-resources-smoke.md`.
