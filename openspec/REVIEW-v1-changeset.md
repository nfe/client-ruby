# Revisão multi-perspectiva — Changeset SDK Ruby NFE.io v1

## Introdução

Este documento sintetiza uma revisão adversarial das **9 changes OpenSpec** que compõem a reescrita
greenfield do SDK Ruby (`gem nfe-io` 0.3.2 → 1.0.0): `add-ruby-foundation`, `add-http-transport`,
`add-openapi-pipeline`, `add-client-core`, `add-entity-resources`, `add-invoice-resources`,
`add-lookup-resources`, `add-rtc-invoice-emission`, `add-release-tooling`. É um artefato de
**planejamento** (nenhum código existe ainda).

### As 6 lentes

1. **API completeness vs nfeio-docs** — cobertura da superfície contra a fonte da verdade (specs OpenAPI + docs).
2. **SDK parity** — paridade com os SDKs Node v4 e PHP de referência.
3. **Ruby feasibility** — idiomas modernos de Ruby e viabilidade zero-dependência (stdlib).
4. **OpenSpec rigor** — consistência cruzada entre changes, nomes, namespaces e contratos.
5. **Security & compliance** — manejo de dados fiscais, segredos, TLS, logging, webhooks.
6. **Release & DX** — release, migração, documentação e experiência de desenvolvedor.

### Método

Cada lente produziu achados; cada achado passou por um veredito adversarial
(**confirmed / partial / refuted**) com verificação direta dos arquivos (specs, tasks, design, docs
fonte-da-verdade, e os SDKs Node/PHP). Esta síntese **deduplicou** achados que múltiplas lentes
levantaram, **descartou os refutados**, manteve os confirmados/parciais e **priorizou por severidade
ajustada** (a severidade pós-verificação, frequentemente menor que a original quando o "gap" era na
verdade paridade deliberada com Node/PHP).

**Resultado:** 22 gaps confirmados (4 alta, 11 média, 7 baixa) e **5 achados refutados**.

---

## Tabela de gaps confirmados

| # | Área | Severidade | Achado | Ação | Change-alvo |
|---|---|---|---|---|---|
| 1 | DX / Erros | alta | MIGRATION/README/skill documentam classes de erro inexistentes (`ConnectionError`, `ValidationError`, `PollingTimeoutError`) | modify-change | add-release-tooling |
| 2 | Release | alta | Tag SemVer com hífen (`v1.0.0-rc.1`) não é prerelease RubyGems válido (precisa `1.0.0.rc.1`) | modify-change | add-release-tooling |
| 3 | Release | alta | Nome do gemspec divergente: foundation cria `nfe-io.gemspec`, release-tooling usa `nfe.gemspec` | modify-change | add-release-tooling |
| 4 | DX / Docs | alta | A página `ruby.md` do nfeio-docs já existe e ensina webhook/API errados — docs é UPDATE, não criação | modify-change | add-release-tooling |
| 5 | OpenSpec rigor | alta→média | Classes `Pending`/`Issued` em TRÊS namespaces contraditórios; RTC sem predicados `pending?`/`issued?` | modify-change | add-rtc-invoice-emission |
| 6 | OpenSpec rigor | alta→média | Downloads RTC de product contradizem o contrato clássico (`String` binária vs `NfeFileResource`/URI) | modify-change | add-rtc-invoice-emission |
| 7 | Ruby feasibility | alta | `from_api` exigido por client-core mas nenhuma change gera/implementa o factory + mapeamento camel→snake + hidratação aninhada | modify-change | add-openapi-pipeline |
| 8 | OpenSpec rigor | média | `AbstractResource` referenciado em dois nomes (`Nfe::AbstractResource` vs `Nfe::Resources::AbstractResource`) | modify-change | add-lookup-resources, add-entity-resources, add-rtc-invoice-emission |
| 9 | OpenSpec rigor | média | Stubs `*_resource.rb` de client-core não batem com `*.rb` das changes de recurso | modify-change | add-client-core |
| 10 | OpenSpec rigor / Erros | média | `PollingTimeoutError`/`ConnectionError`/`ValidationError` em project.md e release-tooling sem classe definida | modify-change | add-release-tooling |
| 11 | SDK parity | média | Retry de POST diverge de Node/PHP e `idempotency_key` não é exposto em nenhum método público | modify-change | add-http-transport, add-invoice-resources |
| 12 | Security | média | `idempotency_key` é slot dormente nunca conectado por recurso — emissão duplicada não é mitigada | modify-change | add-invoice-resources, add-rtc-invoice-emission |
| 13 | SDK parity | média | Sem override de request-options por chamada (PHP expõe `RequestOptions` em todo método) | clarify-with-maintainer | add-client-core |
| 14 | Ruby feasibility / Segurança | média | `Client` estilo Stripe sem requisito de thread-safety; pool de conexão é Hash mutável sem mutex | modify-change | add-http-transport, add-client-core |
| 15 | Security | média→ | Body de request/response logado no erro, mas redação só cobre HEADERS — CNPJ/CPF/senha vazam em log | modify-change | add-http-transport |
| 16 | Security | média | Senha de certificado sem requisito in-memory/never-logged/zeroize | modify-change | add-entity-resources |
| 17 | Security | média | Proteção de replay de webhook nem especificada nem reconhecida como inviável | modify-change | add-entity-resources, add-release-tooling |
| 18 | Security | média | `ca_file` (escape hatch TLS) só na prosa de design, ausente do spec de Configuration | modify-change | add-client-core |
| 19 | OpenSpec rigor | média→baixa | Precedência de config (env var vs args) não especificada; diverge do Node que lê `NFE_API_KEY` | clarify-with-maintainer | add-client-core |
| 20 | DX | média | Sem config de sandbox/teste de primeira classe; dual-axis `environment` (símbolo vs string) confunde | modify-change | add-release-tooling, add-client-core |
| 21 | Release | média→baixa | OIDC trusted publishing: dono admin RubyGems indefinido + fallback de API-key sub-especificado | clarify-with-maintainer | add-release-tooling |
| 22 | DX | média | MIGRATION descreve a API v0.3.x errada (`Nfe.api_key =` vs `Nfe.api_key(...)`); omite `Nfe.configure` e `company_id` por classe | modify-change | add-release-tooling |

Gaps de severidade **baixa** (registro): inscrições municipais ausentes (paridade — aceitar/diferir),
listagem inbound OData (paridade — diferir), product-catalog DTO sem accessor (paridade — diferir),
SERPRO out-of-scope (documentar), switch-authorizer/certs v2 (documentar), CT-e inbound reprocess
(documentar), JWT Bearer auth (documentar como non-goal), proxy HTTP (hardening), `message` de erro
sem cap de tamanho (hardening), supply-chain dev/codegen sem Gemfile.lock pinning (hardening),
forward-compat dos helpers diferidos (consolidar), banner README pós-GA (fechar o loop), RBS template
de `Data` não fixado byte-a-byte (refinar), loader de arquivos gerados não decidido (decidir),
content-length obsoleto pós-gzip (limpeza).

---

## Detalhe — gaps de severidade ALTA

### 1. Erros documentados que não existem no SDK
**Área:** DX / Erros · **Ação:** modify-change → `add-release-tooling`

MIGRATION/README/skill (proposal.md:41, tasks.md:3.8/3.9, spec.md:56) instruem documentar
`Nfe::ConnectionError`/`Nfe::ValidationError`/`Nfe::PollingTimeoutError`. A hierarquia autoritativa
(`add-http-transport/spec.md:114`) define `ApiConnectionError`, `TimeoutError < ApiConnectionError`,
`InvalidRequestError` — **nunca** `ConnectionError`/`ValidationError`. `PollingTimeoutError` não é
definido por change nenhuma (polling foi diferido). Integradores copiando `rescue Nfe::ConnectionError`
escreverão cláusulas que **nunca disparam** — buraco silencioso de correção em tratamento de erro fiscal.

**Recomendação:** corrigir a tabela de erros do MIGRATION/README/skill para a hierarquia real
(`AuthenticationError`, `AuthorizationError`, `InvalidRequestError`, `NotFoundError`, `ConflictError`,
`RateLimitError`, `ServerError`, `ApiConnectionError`, `TimeoutError`, `SignatureVerificationError`,
`ConfigurationError`, `InvoiceProcessingError`). Remover `ConnectionError`/`ValidationError`/`PollingTimeoutError`.
Reconciliar project.md:40. (Ver também gap #10 — mesmo defeito sob a lente OpenSpec.)

### 2. Tag SemVer não vira versão de gem prerelease válida
**Área:** Release · **Ação:** modify-change → `add-release-tooling`

`release.sh` valida `^\d+\.\d+\.\d+(-(rc|beta)\.\d+)?$` (forma com hífen) e grava esse valor literal em
`Nfe::VERSION` (tasks 7.4/7.6). RubyGems exige a forma com **ponto** (`1.0.0.rc.1`) para reconhecer
prerelease — o próprio spec usa `1.0.0.rc.1` no cenário Bundler (spec.md:230). Um gem com
`VERSION = "1.0.0-rc.1"` não é tratado como prerelease, quebrando a garantia "Prerelease not
auto-installed" e a política RC-antes-de-GA; sob RubyGems moderno `gem build` falha.

**Recomendação:** regra explícita — tags git usam `vX.Y.Z(-rc.N)`, mas `Nfe::VERSION` e o gem
publicado usam `X.Y.Z(.rc.N)` (ponto). Mapeamento determinístico (tira `v`; troca `-rc.`/`-beta.` por
`.rc.`/`.beta.`); `release.sh` grava a forma com ponto e taggeia a com hífen. Adicionar step na
release.yml que afirma que a versão do gem construído == versão derivada da tag.

### 3. Nome do gemspec divergente entre changes
**Área:** Release · **Ação:** modify-change → `add-release-tooling`

`add-ruby-foundation` renomeia explicitamente `nfe.gemspec` → `nfe-io.gemspec` (tasks.md:23) e valida
com `gem build nfe-io.gemspec`. `add-release-tooling` referencia exclusivamente `nfe.gemspec`
(tasks 1.1/8.4/11.5, spec.md:6/11, design.md:17). Como release-tooling roda por último, o
`gem build nfe.gemspec` da release.yml mira um arquivo que já não existe — e a falha ocorre **depois**
da tag já ter sido empurrada para origin.

**Recomendação:** padronizar `nfe-io.gemspec` (convenção Bundler para o gem `nfe-io`) em ambas as
changes; atualizar todos os `gem build`/`gem spec` em release.yml e release.sh. (Nota:
`add-openapi-pipeline` também cita `nfe.gemspec` em prosa de `add_dependency` — corrigir junto, embora
não quebre build.)

### 4. A página ruby.md do nfeio-docs já existe e ensina conteúdo errado
**Área:** DX / Docs · **Ação:** modify-change → `add-release-tooling`

A página existe, está viva e git-tracked em `docs/desenvolvedores/bibliotecas/ruby.md`. Contém (1) um
handler de webhook usando `X-NFEIO-Signature` + `Base64.strict_encode64(OpenSSL::HMAC.digest('sha1'...))`
— esquema que o SDK declara errado (o canônico é `X-Hub-Signature` + HMAC-SHA1 hex); (2) a API global
v0.3 (`Nfe.api_key('...')`, `Nfe::ServiceInvoice.company_id(...)`, `.download(...).body`) que a v1
remove. O changeset enquadra o trabalho de docs como **criação** (tasks §10, spec.md:237, design.md:30),
nunca reconhecendo que a página já existe e precisa de remoção de conteúdo errado. Deixar a página como
está é pior que não ter página: ensina um esquema de assinatura que o SDK diz estar quebrado.

**Recomendação:** reescrever o task §10 como "reescrever a `ruby.md` existente". Subtasks explícitas para
remover o snippet `X-NFEIO-Signature`+Base64 e os exemplos `Nfe.api_key(...)` globais, e adicionar o
quickstart `Nfe::Client.new(api_key:)`. Considerar espelhar a estrutura Node
(`migracao-v2.md`/`changelog.md`/`exemplos.md`).

---

## Detalhe — gaps de severidade MÉDIA

### 5. `Pending`/`Issued` em três namespaces contraditórios
**Área:** OpenSpec rigor · **Ação:** modify-change → `add-rtc-invoice-emission` (+ varredura)

Coexistem `Nfe::Pending`/`Nfe::Issued` (client-core spec.md:142), `Nfe::Resources::ServiceInvoicePending`
(invoice-resources spec.md:243-249) e `Nfe::ServiceInvoiceRtcPending` no top-level (RTC spec.md:107-114).
Pior: a cláusula RTC "distinct from the classic `Nfe::ServiceInvoicePending`" referencia um nome que
nenhuma change define (o clássico é `Nfe::Resources::ServiceInvoicePending`). E o RTC nunca declara os
predicados `pending?`/`issued?` que invoice-resources exige — então `result.pending?` do fluxo clássico
falha silenciosamente em resultados RTC.

**Recomendação:** padronizar todos os value objects discriminados sob `Nfe::Resources::` (convenção da
change mais concreta). RTC vira `Nfe::Resources::ServiceInvoiceRtcPending`. Corrigir a cláusula
"distinct from" para o nome certo. Harmonizar os predicados `pending?`/`issued?` entre RTC e invoice.

### 6. Downloads RTC de product contradizem o contrato clássico
**Área:** OpenSpec rigor · **Ação:** modify-change → `add-rtc-invoice-emission`

Os mesmos endpoints de download de product-invoice têm tipos de retorno opostos: clássico exige
`Nfe::Models::NfeFileResource` (URI), "NOT raw bytes" (invoice-resources spec.md:120-122,302-305); RTC
exige `String` ASCII-8BIT (rtc spec.md:245-248, tasks 9.8/10.12). A fonte da verdade resolve o impasse:
`nf-produto-v2.yaml` mostra `/pdf`, `/xml`, `/xml/rejection`, `/xml-epec` etc. retornando `FileResource`
(`{uri}`) — uma URI, não bytes. O Node declara todos como `Promise<NfeFileResource>`. **O clássico está
certo; o lado RTC é o errado.** O RTC é até auto-contraditório (proposal.md:51/design.md:168 dizem que
herda os "tipos de resposta" do clássico = URI).

**Recomendação:** corrigir rtc spec.md:245-248 e tasks 9.8/9.9/10.12 para retornar
`Nfe::Models::NfeFileResource` (URI). Não tocar o clássico.

### 7. Factory `from_api` órfão (hidratação camel→snake + aninhada sem dono)
**Área:** Ruby feasibility · **Ação:** modify-change → `add-openapi-pipeline`

client-core exige `klass.from_api(payload)` (spec.md:128, design D7) em todo DTO. Mas
`add-openapi-pipeline` emite value objects **anêmicos** (`Const = Data.define(...)`, sem `from_api`,
Non-Goals design.md:33). A API devolve chaves camelCase (`federalTaxNumber`) e os atributos são
snake_case (`federal_tax_number`): um Hash JSON cru **não** pode ser splatado no construtor `Data` —
levanta `ArgumentError`. O nome original só vai num **comentário** (não machine-readable). Objetos/arrays
aninhados voltam como Hash/Array, não como os DTOs aninhados que o `.rbs` promete. Ninguém é dono de:
(a) o `from_api` por DTO, (b) o mapa camel→snake em runtime, (c) descarte de chaves desconhecidas, (d)
recursão em refs/arrays aninhados.

**Recomendação:** decidir e atribuir dono: OU `add-openapi-pipeline` gera `from_api` por DTO (mapeia
chaves, ignora desconhecidas, recursa) + emite o `.rbs`; OU `add-client-core` define um `Nfe::Hydrator`
genérico usando os membros do `Data` + mapa camel→snake gerado + tabela de tipos aninhados gerada.
Adicionar cenários para tolerância a chaves desconhecidas e hidratação de arrays aninhados.

### 8. `AbstractResource` em dois nomes
**Área:** OpenSpec rigor · **Ação:** modify-change → lookup/entity/rtc

O dono define `Nfe::Resources::AbstractResource` (client-core spec.md:93,112; tasks 9.1). invoice-resources
usa a forma qualificada. Mas lookup-resources (spec.md:6,8 + tasks), entity-resources (tasks 35,58,81) e
RTC (proposal.md:16 + tasks) declaram `< Nfe::AbstractResource` (sem `Resources::`). São constantes
diferentes em Ruby — as superclasses não resolveriam. Não há alias em lugar nenhum.

**Recomendação:** varrer lookup-resources (spec+tasks), entity-resources (tasks) e RTC (proposal/tasks)
para `Nfe::Resources::AbstractResource`. Opcionalmente apertar a prosa do próprio client-core, que usa a
forma curta informalmente.

### 9. Nomes de arquivo dos stubs não batem com as changes de recurso
**Área:** OpenSpec rigor · **Ação:** modify-change → `add-client-core`

client-core cria 17 stubs com sufixo `_resource` (`service_invoices_resource.rb` etc., tasks 10.1). Toda
change de recurso cria `service_invoices.rb` (sem sufixo). Como são "substituir o stub" greenfield, o
implementador acaba com um arquivo paralelo e um stub `*_resource.rb` órfão (a lista de requires de
client-core ainda exige os stubs sufixados).

**Recomendação:** alinhar os stubs de client-core tasks 10.1 para a convenção sem sufixo
(`service_invoices.rb` / `Nfe::Resources::ServiceInvoices`), tornando a relação "substitui o stub"
exata em nome de arquivo. (Relaciona-se ao gap #8 — corrigir os dois juntos.)

### 10. Nomes de classe de erro inexistentes em project.md/release-tooling
**Área:** OpenSpec rigor / Erros · **Ação:** modify-change → `add-release-tooling`

(Mesmo defeito do gap #1, visto pela lente de consistência cruzada.) project.md:40 e release-tooling
listam `ValidationError`/`ConnectionError`/`PollingTimeoutError`; nenhuma é definida pelas changes. As
classes de erro reais SÃO especificadas (client-core tasks.md 2.1-2.3 define `ConfigurationError`,
`InvalidRequestError`, `InvoiceProcessingError` com pais), então o gap é a **varredura de nomes
canônicos**, não classes faltando.

**Recomendação:** sweep de project.md:40 e release-tooling para os nomes canônicos
(`InvalidRequestError`, `ApiConnectionError`); remover `PollingTimeoutError` (polling diferido).

### 11. Retry de POST diverge de Node/PHP e `idempotency_key` é inalcançável
**Área:** SDK parity · **Ação:** modify-change → `add-http-transport` + `add-invoice-resources`

Node e PHP retentam qualquer 5xx/429 independente do método; Ruby (corretamente, por segurança) **não**
retenta POST não-idempotente. Mas nenhum método `create()` aceita `idempotency_key:`/`options:`, então o
caller não consegue reativar a elegibilidade de retry — o slot `idempotency_key` do `Request` é
inalcançável pela API pública. A decisão de segurança está bem justificada no design interno (D8/D9), mas
**não** está nos docs voltados ao integrador.

**Recomendação:** (a) documentar a divergência no README (não no MIGRATION, que mira usuários v0.3.x);
(b) expor `idempotency_key:` nos métodos `create()`/`create_with_state_tax()` para tornar a emissão
retry-elegível.

### 12. `idempotency_key` é slot dormente — emissão duplicada não mitigada
**Área:** Security · **Ação:** modify-change → `add-invoice-resources` + `add-rtc-invoice-emission`

D9 delega geração (`SecureRandom.uuid`) e a decisão de "quando habilitar" à camada de recurso — que nunca
o faz. Nenhum `create` gera/envia uma key. Em timeout de rede após o servidor já ter criado a invoice, o
retry natural do caller pode emitir documento duplicado. (A proteção "não auto-retentar POST" É entregue;
o risco residual é o retry do **caller**, e depende de o API honrar o header.)

**Recomendação:** OU conectar (kwarg `idempotency_key:` default `SecureRandom.uuid`, enviado como header,
com requisito + cenário) OU escopar explicitamente para fora com um requisito documentando que a v1 não
garante emissão at-most-once e instruindo o caller a fazer retrieve-by-business-key antes de retentar.

### 13. Sem override de request-options por chamada
**Área:** SDK parity · **Ação:** clarify-with-maintainer → `add-client-core`

PHP expõe `?RequestOptions $options = null` em todo método (apiKey/baseUrl/timeout por chamada). Ruby
configura só no nível do `Client`. Um migrante PHP perde a capacidade de sobrescrever timeout/baseUrl e,
sobretudo, **apiKey por chamada (multi-tenant)** sem reconstruir o Client. (Nota: PHP NÃO carrega
idempotencyKey no RequestOptions — o gap real é apiKey/baseUrl/timeout.)

**Recomendação:** decisão de escopo do mantenedor — adicionar `request_options:` por chamada (ao menos
nos POST de emissão) OU documentar em design.md que overrides por chamada são deliberadamente diferidos
para um minor futuro e que o caller constrói um segundo Client.

### 14. Sem requisito de thread-safety para Client estilo Stripe
**Área:** Ruby feasibility / Segurança · **Ação:** modify-change → `add-http-transport` + `add-client-core`

O SDK promove explicitamente o padrão Stripe de Client compartilhado (acessores lazy memoizados via
`||=`, não-sincronizados), mas o pool de conexão por origem é um `Hash` mutável sem mutex e a thread-safety
aparece **só** numa "Open Question" do design (não como requisito). Rails/Sidekiq/Puma compartilharão um
Client entre threads, causando data races no pool e nos acessores.

**Recomendação:** decisão v1 — (a) mutex no pool e nos acessores lazy (barato, torna o padrão seguro), OU
(b) `NetHttp` abre conexão por chamada (sem pool mutável). Adicionar requisito + cenário declarando a
garantia de thread-safety. Não deixar em "Open Questions" para um SDK de emissão fiscal.

### 15. Body logado no erro, mas redação só cobre headers
**Área:** Security · **Ação:** modify-change → `add-http-transport`

No erro, o logger loga "status + corpo truncado" (corpo = RESPONSE body) e o `Nfe::Error` retém
`response_body`. A redação só cobre valores de **headers** sensíveis — nada redige segredos/PII dentro do
body. Respostas 422/500 verbosas podem ecoar CNPJ/CPF e dados do tomador/comprador para o log. (Nuance: o
REQUEST body — incluindo o multipart com `password` do certificado — não é input do logger; e `Error#to_h`
já é escopado e não inclui o body. O vetor real é a linha de log do response-body truncado e o atributo
`Error#response_body`.)

**Recomendação:** requisito explícito — não logar request/response body por default (logar só método,
URL, status, request_id); gatear qualquer log de body atrás de flag opt-in. Adicionar cenário afirmando
que segredos/PII não aparecem em nenhuma linha de log.

### 16. Lifecycle da senha de certificado sem requisito de segurança
**Área:** Security · **Ação:** modify-change → `add-entity-resources`

A senha PKCS#12 passa por `validate_certificate` e `upload_certificate` como String Ruby comum. Nada
declara que a senha (ou bytes do .pfx / chave privada) deve ficar só em memória, nunca em disco, nunca em
log/exceção, e idealmente ser zerada após uso — embora o changeset estabeleça exatamente essa postura de
compliance para headers. (Gap latente/de documentação: não há vazamento ativo hoje, pois o request body
não é logado e `to_h` é escopado; mas o requisito defensivo está ausente.)

**Recomendação:** requisito em add-entity-resources: a senha e os bytes PKCS#12 SHALL ser manejados só em
memória, SHALL NOT ser persistidos em disco, SHALL NOT aparecer em log/exceção/Error, e (onde viável) a
String da senha SHALL NOT ser retida além da chamada de upload. Cenários: "senha ausente dos logs" e
"senha ausente de qualquer exceção / Error#to_h".

### 17. Proteção de replay de webhook não especificada
**Área:** Security · **Ação:** modify-change → `add-entity-resources` + `add-release-tooling`

O spec de webhook especifica HMAC-SHA1 sobre os bytes do body, mas nada sobre replay. A NFE.io envia só
`X-Hub-Signature` — sem timestamp/nonce/delivery-id. Uma assinatura válida capturada e reenviada passa em
`verify_signature` para sempre.

**Recomendação:** (a) requisito documentando que a NFE.io não fornece primitiva anti-replay, instruindo o
consumidor a deduplicar pelo id do evento/invoice e tratar handlers como idempotentes (e `construct_event`
expor um id estável quando presente); no mínimo o README/skill deve avisar que validade de assinatura ≠
frescor e que handlers devem ser idempotentes.

### 18. `ca_file` (escape hatch TLS) só na prosa de design
**Área:** Security · **Ação:** modify-change → `add-client-core`

O design promete `Configuration#ca_file` como escape hatch documentado, mas a lista de opções de
Configuration (client-core spec.md:20-21) não o inclui, e o requisito de TLS só manda `VERIFY_PEER`.
Deixa espaço para um implementador adicionar um toggle inseguro `verify_mode` em vez disso. (Mitigação
parcial: http-transport spec.md:25 já proíbe desabilitar verificação por default.)

**Recomendação:** especificar `ca_file` (e opcionalmente `ca_path`) na lista de opções como o ÚNICO
override de confiança TLS, com requisito de que só pode ADICIONAR/substituir bundle de CA e SHALL NEVER
expor `VERIFY_NONE`/`insecure_ssl`. Cenário afirmando que não há API pública para desabilitar verificação.
Esclarecer que o `insecureSsl` do spec nf-consumidor-v2 é atributo server-side do alvo do webhook, NÃO o
TLS de saída do SDK.

### 19. Precedência de config (env var vs args) não especificada
**Área:** OpenSpec rigor · **Ação:** clarify-with-maintainer → `add-client-core`

A resolução de chaves é puramente sobre args do construtor; nada trata fallback de env var. O Node de
referência (paridade declarada) LÊ env internamente (`config.dataApiKey || config.apiKey || NFE_DATA_API_KEY
|| NFE_API_KEY`). O cenário Ruby "Missing all keys" levanta erro sem chave passada — divergindo do Node
quando env vars estão setadas. (A metade de thread-safety deste achado original já está coberta no design.)

**Recomendação:** decisão do mantenedor — OU especificar fallback de env com ordem "arg explícito vence"
(igual ao Node) OU declarar explicitamente que a v1 NÃO lê env.

### 20. Sem config de sandbox/teste de primeira classe
**Área:** DX · **Ação:** modify-change → `add-release-tooling` + `add-client-core`

`:production`/`:development` resolvem para a MESMA URL, diferindo só pela chave — mas nada documenta como o
usuário obtém/aponta credenciais de sandbox, e não há sample de env de teste. Pior: product/consumer
invoice exigem `environment: "Production"/"Test"` como STRING por chamada — um eixo diferente do símbolo
`:development` do client (pitfall que o skill Node sinaliza). (Parcialmente coberto: o modelo "símbolo
seleciona chave, não URL" já está no spec/design.)

**Recomendação:** seção README/skill "Sandbox vs Production": (a) o símbolo seleciona chave, não URL;
(b) como obter credenciais de teste; (c) que invoice de product/consumer usa um param string `environment`
SEPARADO. Um sample mostrando emissão em ambiente Test.

### 21. OIDC trusted publishing: ownership e fallback abertos
**Área:** Release · **Ação:** clarify-with-maintainer → `add-release-tooling`

Open Questions admite que "quem tem acesso admin da conta nfe-io no RubyGems" é desconhecido, e a duração
do beta é indecisa — ambos GA-blockers. O fallback `RUBYGEMS_API_KEY` não tem task de provisão/rotação, e
não há nota sobre a interação MFA-vs-push-CI (`rubygems_mfa_required => true`).

**Recomendação:** antes de cortar rc.1: (1) confirmar admin RubyGems e fazer o binding de trusted
publisher, ou provisionar `RUBYGEMS_API_KEY` como chave push-only escopada (+ task para armazená-la);
(2) verificar que `rubygems_mfa_required` não bloqueia o push de CI no método escolhido; (3) fixar a
janela de beta (recomendado 14 dias para SDK fiscal) para tornar §12.3 testável.

### 22. MIGRATION descreve a API v0.3.x errada
**Área:** DX · **Ação:** modify-change → `add-release-tooling`

O lado "antes" usa `Nfe.api_key = "..."` (atribuição), mas o legado define `def self.api_key(api_key)` —
um setter de método chamado `Nfe.api_key('...')`. A sibling change `add-ruby-foundation` usa a forma certa,
então o changeset se **auto-contradiz**. Faltam também o bloco `Nfe.configure { |c| c.url= }` e o
state por classe `Nfe::ServiceInvoice.company_id("...")` — exatamente as linhas que os usuários copiaram do
README legado.

**Recomendação:** corrigir o "antes" para `Nfe.api_key('...')` (forma de método) e adicionar a migração de
`Nfe.configure { |c| c.url = ... }` e do padrão `Nfe::ServiceInvoice.company_id(...)` → `client.service_invoices.create(company_id:, ...)`.

---

## Gaps de severidade BAIXA (registro / hardening)

Itens reais mas de baixo impacto, em sua maioria **paridade deliberada** com Node/PHP ou hardening
defensivo. Recomendação geral: registrar como non-goal consciente ou diferir.

- **Inscrições municipais ausentes** (sem `municipal_taxes`): gap herdado de Node E PHP; a alegação "17
  recursos = PHP 1:1" está correta. **Ação: aceitar-as-is** e registrar como gap conhecido-mas-diferido em
  CHANGESET-OVERVIEW.md (opcionalmente liderar os outros SDKs adicionando depois).
- **Listagem inbound OData ausente** (sem `list`/`list_events` em InboundProductInvoices/TransportationInvoices):
  omissão intencional em toda a família (Node e PHP não têm). **Ação: aceitar-as-is**, registrar em "Fora de escopo".
- **Product-catalog DTO sem accessor**: padrão cross-SDK deliberado (PHP tem os DTOs gerados sem resource).
  **Ação: aceitar-as-is** (já coberto pela decisão de superfície de 17 recursos).
- **CT-e inbound reprocess/batch/consolidation ausentes**: nenhum SDK de referência implementa.
  **Ação: aceitar-as-is**, opcionalmente adicionar `reprocess_webhook` por simetria com NF-e.
- **NFS-e clássica `download_cancellation_xml`**: a capacidade existe via `service_invoices_rtc` (Ambiente
  Nacional). **Ação: modify-change** (add-invoice-resources) — só adicionar um cross-reference doc.
- **`retrieve_by_external_id` ausente**: consistente com baseline Node. **Ação: aceitar-as-is** (idempotência
  já coberta como conceito distinto).
- **Variantes SERPRO ausentes**, **switch-authorizer + certs v2**: ambos consistentes com Node 1:1.
  **Ação: aceitar-as-is** — adicionar uma linha em "Não inclui (fora de escopo)".
- **JWT Bearer auth**: consistente com Node/PHP (só X-NFE-APIKEY). **Ação: aceitar-as-is** — registrar como
  deferral consciente em project.md/design.
- **Proxy HTTP ausente**: não é regressão de paridade (Node/PHP também não expõem). **Ação: modify-change**
  (add-client-core) — `Configuration#proxy` é um one-liner de stdlib; barato.
- **`message` de erro sem cap de tamanho/scrub**: pode ecoar input do servidor. **Ação: modify-change**
  (add-http-transport) — capar tamanho e documentar que pode conter input ecoado.
- **Supply-chain dev/codegen sem Gemfile.lock pinning**: decisão deliberada (não commitar lock é convenção
  para gem-lib). **Ação: clarify-with-maintainer** — preferir `bundler-audit`/dependabot em CI a commitar lock.
- **Forward-compat dos helpers diferidos**: promessas existem mas espalhadas. **Ação: modify-change**
  (add-release-tooling) — consolidar uma linha declarando Pending/Issued + FlowStatus como API pública estável.
- **Banner README pós-GA**: existe task para adicionar, falta task para remover no GA. **Ação: modify-change**
  (add-release-tooling) — amarrar o estado do banner ao fluxo prerelease-vs-final do release.sh.
- **content-length obsoleto pós-gzip**: cosmético (body é a fonte da verdade). **Ação: modify-change**
  (add-http-transport) — remover/recomputar content-length após inflar.
- **RBS template de `Data` / loader de arquivos gerados**: decisões abertas registradas. **Ação:
  clarify-with-maintainer / modify-change** (add-openapi-pipeline) — fixar template `< Data` e decidir
  `require_relative` explícito.

---

## Sugestões de novas changes

Nenhuma área de capacidade inteira está faltando que justifique uma nova change OpenSpec autônoma. Todos
os gaps confirmados são corrigíveis dentro das 9 changes existentes (modify-change) ou são non-goals a
registrar. A maior parte das "ausências de cobertura" verificou-se como **paridade deliberada** com os SDKs
Node/PHP, não como lacunas reais.

Único candidato fraco a futura change (pós-v1, opcional, não-bloqueante):

- **`add-municipal-taxes`** — recurso `municipal_taxes` (CRUD + `series/{serie}` + `updateprefecture`) que
  lideraria os SDKs Node/PHP. Só se inscrição municipal virar necessidade de negócio próxima; caso
  contrário, registrar como gap conhecido e seguir.

---

## Verificado e OK (áreas bem cobertas)

A revisão confirmou que vastas porções do changeset estão sólidas. Registrado para mostrar amplitude:

- **Multipart de upload de certificado é viável e tem dono** (refutado o "incompatível com o contrato"):
  `AbstractResource#upload_multipart` usando `Net::HTTP::Post#set_form` está in-scope em add-entity-resources
  (tasks 2.1, design D6). `Net::HTTP` tem multipart na stdlib (diferente do PHP/cURL que precisou diferir).
- **Gzip / Accept-Encoding manual**: o gotcha do Net::HTTP (desabilitar auto-decompress) está antecipado e
  tratado via `Zlib::GzipReader` com fallback em `Zlib::Error` (D5, tasks 2.8); só content-length residual.
- **Encoding ASCII-8BIT / ownership de body**: D4 atribui ownership UMA vez (transport "burro" devolve bytes
  crus; camada de recurso decide JSON vs download). O `force_encoding` no helper é re-asserção idempotente,
  não ambiguidade; o `.dup` é prática defensiva correta (sem FrozenError real).
- **RBS de `Data.define`**: a estratégia (emitir `class <Const> ... end` com atributos tipados + assinatura
  do construtor) já está especificada (pipeline tasks 4.8, spec.md:56) e validada em CI (3.2/3.3/3.4 via
  `rbs validate` + `steep check`).
- **RTC adicionando acessores ao Client (17→19)**: NÃO é inconsistência (refutado). O spec de client-core é
  um contrato aberto deliberado ("at least seventeen ... opt-in changes MAY register further"); a edição de
  client.rb está totalmente disclosed (proposal.md:79, design D9). "Modified Capabilities vazio" é correto
  porque não há spec arquivada para modificar.
- **Campo multipart `file` (não `certificate`)**: Ruby segue corretamente o spec OpenAPI e a divergência do
  Node já está documentada (design D6, tasks 4.12) — refutada a alegação de que faltava documentar.
- **`environment` selects key, not URL**: o modelo está correto e end-to-end documentado (D3); confirmado
  contra o PHP `Config.php` que NÃO ramifica por environment. Só wording "sandbox" a apertar.
- **`get_status` derivado de `retrieve`**: entregue, não diferido (refutada a alegação de que MIGRATION o
  trata como ausente — o parêntese inline já esclarece "derivado no v1").
- **Streaming de download + read_timeout per-call**: deferral de streaming está explicitamente listado em 3
  lugares e read_timeout JÁ é configurável por Request (refutadas as duas metades).
- **Gate de cobertura SimpleCov ≥80% e abstração de transport substituível**: ambos são requisitos de
  capability de primeira classe (sdk-foundation spec.md:164; http-transport spec.md:6-10).
- **Hierarquia de erro core (`ConfigurationError`/`InvalidRequestError`/`InvoiceProcessingError`)**: SÃO
  especificadas (em client-core tasks §2 com pais), e a escolha `InvalidRequestError` sobre `ValidationError`
  é deliberada e justificada (design.md:145). O defeito real é só a varredura de nomes nos docs (gaps #1/#10).
- **Publicação endurecida**: OIDC trusted publishing, `rubygems_mfa_required`, `.gem` + `.sha256` checksum,
  guarda de drift do spec via SHA-256 — tudo presente em add-release-tooling.

---

*Relatório gerado a partir da síntese adversarial das 6 lentes. 22 gaps confirmados, 5 refutados.*
