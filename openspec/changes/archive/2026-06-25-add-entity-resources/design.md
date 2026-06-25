# Design — add-entity-resources

## Context

**add-client-core** entregou o terreno: `Nfe::Client` com 17 acessores lazy snake_case, `Nfe::Configuration` com o host map multi-base-URL, `Nfe::Resources::AbstractResource`, o contrato 202 discriminado (`Pending`/`Issued`), `Nfe::FlowStatus`, `Nfe::ListResponse` e as exceções tipadas. Esta change é o **primeiro consumidor real** desses blocos no grupo de entidades.

Os 4 recursos desta change rodam todos no host **principal** (`main` → `base_url_for(:main)` retorna `https://api.nfe.io`; o `/v1` vem do `api_version` do recurso, URL efetiva `https://api.nfe.io/v1/...`). Diferente dos invoice resources (que se espalham por `api.nfse.io`, `nfe.api.nfe.io` etc.), aqui não há roteamento exótico: todos resolvem via `Configuration#base_url_for(:main)`.

Dois perfis distintos:

- **CRUD de entidade** (companies, legal_people, natural_people): create/list/retrieve/update/delete com envelopes `{"<plural>" => ...}`, mais helpers de conveniência (`find_by_*`).
- **Segurança + gestão de notificação** (webhooks): CRUD de subscrição + `test` + lista estática de eventos, e — separado do recurso, como capability própria — o módulo `Nfe::Webhook` para verificar a assinatura HMAC de entregas recebidas.

A canonicidade do esquema de assinatura (HMAC-SHA1 + `X-Hub-Signature`, bytes crus, hex maiúsculo, prefixo `sha1=`) está fundamentada em três fontes independentes:

1. `docs/documentacao/webhooks/duvidas-frequentes.md:33` — "Segredo... gerar o valor do HMAC em hexadecimal... no cabeçalho HTTP X-Hub-Signature. O HMAC será gerado baseado no(s) bytes do evento de notificação."
2. `docs/documentacao/webhooks/ips-de-origem.md:44-45` — "Cabeçalho X-Hub-Signature, no formato sha1=<hash>. Algoritmo HMAC-SHA1."
3. Probe ao vivo (registrado em `client-nodejs/openspec/changes/fix-webhook-signature-verification`): `sha1=BCD17C02B9E3B40A18E745E7E04247E4AD2DD935`, confirmado em registros product/service/mixed, registro global único em `api.nfse.io`.

## Goals / Non-Goals

**Goals**
- 4 recursos com paridade método-por-método com o SDK Node, adaptados a idiomas Ruby (snake_case, keyword args, `Data.define`, retornos síncronos, `String` binária para downloads — embora estes recursos quase não tenham downloads).
- Gestão de certificado **completa** (upload + replace + validate local), indo **além** do PHP v3.0 que diferiu isso, aproveitando `Net::HTTP#set_form` (multipart) e `OpenSSL::PKCS12` (parse real) da stdlib — sem nenhuma dependência de runtime nova.
- Módulo `Nfe::Webhook` que torne a verificação de assinatura uma linha de código no caller, sem precisar instanciar `Client`, com `OpenSSL.secure_compare` (constante).
- `verify_signature` **nunca levanta exceção**; `construct_event` levanta `Nfe::SignatureVerificationError` apenas em assinatura inválida.
- 100% dos métodos com validação fail-fast de ID via os helpers de **add-client-core** antes de qualquer HTTP.

**Non-Goals**
- `create_and_wait` / `create_batch` concorrente — pertencem aos invoice resources / release futura. `create_batch` aqui é loop sequencial.
- Iterador `Enumerator::Lazy` sofisticado de paginação — `list_each` (Enumerator simples) é suficiente para v1.
- Validação de check-digit de CNPJ/CPF no cliente — colide com CNPJ alfanumérico (jul/2026); deixamos para o servidor.
- Otimização de `find_by_*` e `get_companies_with_*` — replicamos o Node (N+1) como conveniência, sem rate-limit smartness.
- Suporte ao esquema antigo `X-NFe-Signature`/SHA-256 — explicitamente não-suportado (é um bug da documentação de distribuição).

## Decisions

### D1. `Nfe::Webhook` é um módulo de funções, sem dependência do `Client`
**Decisão**: `module Nfe::Webhook` com `module_function`. Não recebe `Client`, não lê `Configuration`. O caller passa `secret` direto.

```ruby
event = Nfe::Webhook.construct_event(
  payload:   request.body.read,                       # bytes crus, ANTES do JSON.parse
  signature: request.get_header("HTTP_X_HUB_SIGNATURE"),
  secret:    ENV.fetch("NFE_WEBHOOK_SECRET"),
)
```

**Por quê**: verificação de webhook é 100% offline — não precisa de credencial de API. O caller típico é um endpoint Rack/Rails/Sinatra onde nenhum `Nfe::Client` está no escopo. `Stripe::Webhook.construct_event` faz exatamente isso. Como a capability é independente do `Client`, ela ganha um `spec.md` separado (`webhook-signature-verification`).

**Alternativa rejeitada**: método de instância `client.webhooks.verify_signature(...)` (o que o Node faz). Funciona, mas obriga a ter um `Client` configurado num lugar onde só se quer validar bytes. Manteremos um **alias** de instância `Nfe::Client#webhooks.verify_signature` delegando ao módulo, para paridade Node, mas a API canônica é o módulo estático.

### D2. Dois níveis de API: `verify_signature` (Boolean) e `construct_event` (DTO)
**Decisão**:
- **Low-level** (paridade com `validateSignature` do Node): `verify_signature(payload:, signature:, secret:) -> Boolean`. Nunca levanta.
- **High-level** (preferido, ergonômico): `construct_event(payload:, signature:, secret:) -> Nfe::WebhookEvent`. Verifica, parseia o JSON e desembrulha o envelope; levanta `Nfe::SignatureVerificationError` em mismatch e `Nfe::SignatureVerificationError` (subclasse ou variante) em JSON malformado.

**Por quê**: caller que quer logar assinaturas inválidas sem virar 500 usa o Boolean; caller comum usa `construct_event` e segue com `event.type`/`event.data`.

### D3. Verificação de assinatura: bytes crus, prefixo `sha1=`, hex case-insensitive, `OpenSSL.secure_compare`
**Decisão**: o algoritmo de `verify_signature`, passo a passo (espelhando o `validateSignature` corrigido do Node, em Ruby):

1. Retorna `false` se `secret` for `nil`/vazio ou `signature` for `nil`.
2. Normaliza o header: se vier `Array` (cabeçalho repetido), pega `[0]`. Se não for `String` não-vazia, `false`.
3. Exige e remove o prefixo `sha1=` (comparação do prefixo case-insensitive). Sem prefixo correto → `false`. **Recusa downgrade**: `sha256=...` → `false`.
4. Faz `downcase` no hex restante e valida a forma com `/\A[a-f0-9]{40}\z/` (HMAC-SHA1 é sempre 40 hex / 20 bytes). Forma errada → `false`.
5. Calcula `expected = OpenSSL::HMAC.hexdigest("SHA1", secret, body)` sobre os **bytes crus** do payload (sem reserializar JSON). Se o caller passar `String`, usa como está (já são os bytes recebidos); o caller é instruído a ler `request.body.read` antes do parse.
6. Compara com `OpenSSL.secure_compare(received_hex, expected_hex)` (tempo constante). Como ambos têm 40 chars garantidos, `secure_compare` é seguro.

**Por quê**: `OpenSSL.secure_compare` é a primitiva de comparação constante da stdlib Ruby (existe desde Ruby 2.x via `openssl`), análoga ao `crypto.timingSafeEqual` do Node e ao `hash_equals` do PHP. Comparar a forma hex (case-normalizada) evita o problema de `Buffer.from(hex)` que o Node teve. Validar a forma antes evita alimentar lixo no compare.

**Por quê não decodificar para bytes antes de comparar**: `OpenSSL.secure_compare` opera sobre strings de mesmo comprimento; 40 chars hex normalizados são suficientes e mais simples que decodificar para 20 bytes. A normalização de case (`downcase` nos dois lados) cobre a maiúscula-na-rede da NFE.io.

### D4. Header tolerante: aceita com e sem prefixo? — **exige prefixo `sha1=`**
**Decisão**: `verify_signature` **exige** o prefixo `sha1=` (o formato canônico que a NFE.io envia em `X-Hub-Signature`). Hex puro sem prefixo → `false`.

**Por quê**: a produção sempre envia `sha1=<hex>`. Exigir o prefixo (e recusar `sha256=`) é defesa contra confusão de algoritmo (vetor de CVE histórico em libs de webhook). Isso difere da decisão "aceita com ou sem prefixo" do PHP, mas alinha-se ao comportamento real e mais seguro confirmado no probe do Node. Documentamos: passe o valor bruto do header.

### D5. `OpenSSL::PKCS12` faz validação **real** do certificado (vs magic-byte do Node)
**Decisão**: `companies.validate_certificate(file:, password:)`:
- Lê os bytes do .pfx/.p12 (aceita caminho de arquivo `String`/`Pathname` que é lido, ou os bytes já carregados como `String`).
- `pkcs12 = OpenSSL::PKCS12.new(der_bytes, password)` — isto **levanta `OpenSSL::PKCS12::PKCS12Error` em senha errada ou DER inválido**. Capturamos e levantamos `Nfe::InvalidRequestError` com mensagem clara em pt-BR.
- Extrai do `pkcs12.certificate`: `subject.to_s`, `issuer.to_s`, `not_before`, `not_after`, `serial.to_s`.
- Retorna `Nfe::CertificateInfo` (Data.define) com esses campos. `days_until_expiration` derivado de `not_after`.

**Por quê**: o validador do Node é raso — só checa magic-byte `0x3082` e **fabrica** metadata (`subject: "Certificate Subject"`, `valid_to: now+365d`). O Ruby tem `OpenSSL::PKCS12` na stdlib, então fazemos o parse de verdade: validamos a senha de fato e extraímos a data de expiração real. É o "fix" #2 anotado no recon (o Node faz a checagem rasa; o Ruby deve usar `OpenSSL::PKCS12`).

**Alternativa rejeitada**: replicar a checagem de magic-byte. Rejeitada — é fraca e nasceria com a mesma dívida do Node.

### D6. `upload_certificate` usa multipart nativo do `Net::HTTP`
**Decisão**: incluir `upload_certificate(company_id, file:, password:, filename: nil)` e `replace_certificate(...)` (alias) no v1.
- Pré-valida formato (extensão `.pfx`/`.p12`) e roda `validate_certificate` (parse local) antes do upload — fail-fast.
- Monta `multipart/form-data` com os campos `file` (binário) e `password`, seguindo o spec OpenAPI: NFS-e v1 declara `POST /v1/companies/{company_id}/certificate` com partes `file` + `password`; v2 usa `/certificates` plural com `file` + `password`. O v1 Ruby segue o **nome de campo do spec** (`file`), não o `certificate` que o código Node usa por divergência.
- Delega a montagem multipart ao transport de **add-http-transport** (`Net::HTTP::Post#set_form([[...]], "multipart/form-data")`).

**Por quê**: o PHP diferiu por não ter multipart no `CurlTransport`. O Ruby não tem essa limitação — `Net::HTTP` faz multipart nativamente. Entregar upload no v1 fecha o ciclo de cadastro de company (sem certificado, a company não emite nada), e a stdlib resolve sem gem nova, mantendo a regra de zero dependências de runtime.

**Coordenação**: depende de o transport de add-http-transport expor um caminho que aceite corpo multipart (não só `String`). Registrado como dependência de implementação em tasks §2.

### D7. Envelopes desembrulhados por recurso, não na base
**Decisão**: cada recurso conhece e desembrulha sua própria chave de envelope antes de hidratar o `Data.define`. A `AbstractResource` não sabe de envelopes.

```ruby
# companies:       payload["companies"]
# legal_people:    payload["legalPeople"]
# natural_people:  payload["naturalPeople"]
# webhooks:        sem envelope (resposta plana) — list usa o ListResponse padrão
```

**Por quê**: cada endpoint conhece seu próprio envelope; centralizar na base vira uma chuva de `if`s. Espelha a decisão D3/D6 dos changes PHP e do Node (`response.data.companies`, `response.data.legalPeople`).

### D8. Companies usa paginação page-style; converte 1-based → 0-based
**Decisão**: `companies.list(page_index:, page_count:)` usa paginação page-style. A API retorna `{"companies" => [...], "page" => N}` com `page` 1-based; o recurso converte para `page_index` 0-based no `Nfe::ListResponse` retornado (paridade exata com o Node `response.data.page - 1`). `list_all` itera com `page_count: 100` até a página vir com menos de 100 itens. `list_each` retorna um `Enumerator` que faz o mesmo loop sob demanda.

**Por quê**: paridade com o Node. `legal_people`/`natural_people` **não** têm parâmetros de paginação na assinatura Node (`list(company_id)` retorna a lista inteira em `{"<plural>" => [...]}`), então seu `list` não converte página — só desembrulha.

### D9. `find_by_*` e `get_companies_with_*` são conveniências client-side
**Decisão**: implementação trivial — `list_all` + filtro em Ruby. RDoc/YARD marca como "para contas pequenas; contas grandes devem filtrar no servidor". `get_companies_with_certificates` / `get_companies_with_expiring_certificates` fazem `list_all` + N chamadas a `get_certificate_status` (N+1), capturando erros por company (pula a que falhar), igual ao Node.

**Por quê**: paridade + ergonomia para o caso comum. Quem tem 10.000 entidades não usa isso.

### D10. `webhooks.test` chama `POST /test`; `get_available_events` é lista estática
**Decisão**: `test(company_id, webhook_id)` faz `POST /companies/{id}/webhooks/{webhook_id}/test` e retorna `{ success:, message: }` (Hash simples ou `Data.define`). `get_available_events` retorna a lista estática hard-coded (paridade Node):

```ruby
%w[
  invoice.issued invoice.cancelled invoice.failed invoice.processing
  company.created company.updated company.deleted
]
```

**Por quê**: o Node faz exatamente isto (constante hard-coded). A API tem `/webhooks/eventtypes`, mas o Node não chama; mantemos paridade. Os 7 eventos são superset do union de tipos do Node (que lista só 4) — replicamos os 7 que o `getAvailableEvents` retorna.

### D11. `Nfe::WebhookEvent` é `Data.define` mínimo e desembrulha o envelope de entrega
**Decisão**:

```ruby
Nfe::WebhookEvent = Data.define(:type, :data, :id, :created_at)
```

`construct_event` aceita o envelope de entrega da NFE.io e normaliza: `{"action" => t, "payload" => d}` ou `{"event" => t, "data" => d}` → `WebhookEvent.new(type: t, data: d, id: ..., created_at: ...)`. `data` é um `Hash` opaco; o caller refina conforme o `type`.

**Por quê**: payloads de webhook variam; um DTO mínimo evita falsas garantias. Imutável (`Data.define`) por consistência com o resto do SDK.

### D12. CNPJ/CPF: validar formato/comprimento, NÃO check-digit, NÃO coagir para Integer
**Decisão**: no `companies.create`/`update` e nos `find_by_tax_number`, normalizamos o tax number para dígitos (string) e validamos só formato/comprimento via os helpers de **add-client-core**. **Não** rodamos algoritmo de dígito verificador e **não** convertemos para `Integer`.

**Por quê**: o `validateCNPJ` do Node assume CNPJ puramente numérico — incompatível com o **CNPJ alfanumérico** (IN RFB 2.229/2024, vigente jul/2026, letras nas 12 primeiras posições, dígitos verificadores ainda numéricos). Coagir para `Integer` quebraria o formato novo. O check-digit é validado no servidor; replicá-lo no cliente seria uma armadilha de v1.

## Risks / Trade-offs

| Risco | Mitigação |
|---|---|
| API muda o esquema de assinatura (ex.: para SHA-256) sem aviso | Esquema confirmado por 3 fontes + probe ao vivo; um parâmetro de algoritmo interno permite estender sem breaking change; fixtures de teste quebram cedo se a produção mudar |
| Caller computa HMAC sobre JSON reserializado (`payload.to_json`) em vez dos bytes crus → sempre `false` | RDoc + README mostram `request.body.read` ANTES do parse; bloco de aviso explícito; é a falha #1 mais comum de integradores |
| Envelopes (`{"companies" => {...}}`) inconsistentes entre endpoints | Cada método tem fixture de teste; mismatch falha no spec |
| `upload_certificate` depende de o transport (add-http-transport) aceitar corpo multipart | Coordenado em design D6 + tasks §2; se o transport só aceitar `String`, esta change inclui a extensão multipart mínima |
| `OpenSSL::PKCS12.new` pode levantar em certificados de cadeia incomum (não só senha errada) | Capturamos `OpenSSL::PKCS12::PKCS12Error` genericamente e levantamos `Nfe::InvalidRequestError` com a mensagem original anexada em `details` |
| `find_by_tax_number` lento em contas grandes | Documentado como conveniência; alternativa é filtro server-side (não exposto ainda) |
| Endpoint de `webhooks.test` diverge entre specs (`/test` vs `/pings/test`) | Smoke test em sandbox antes do GA; ajustar path se necessário |
| `OpenSSL.secure_compare` indisponível em build de Ruby sem openssl | openssl é stdlib padrão e está na lista de libs permitidas das decisões canônicas; CI roda em 3.2/3.3/3.4 com openssl presente |
