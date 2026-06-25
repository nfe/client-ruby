# Design — add-client-core

## Context

A reescrita greenfield do SDK Ruby v1 monta o terreno (**add-ruby-foundation**), a camada HTTP (**add-http-transport**) e os DTOs gerados (**add-openapi-pipeline**) antes desta change. `add-client-core` é a **superfície pública** que amarra os três blocos, no modelo do SDK Node (`NfeClient`) e do SDK PHP (`Nfe\Client`), porém idiomático em Ruby moderno.

Filosofia de referência (estilo Stripe, cliente único + acessores):

```ruby
# Stripe-ruby
stripe = Stripe::StripeClient.new("sk_test_...")
customer = stripe.v1.customers.create(...)

# Nfe v1 (alvo)
client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))
invoice = client.service_invoices.retrieve(company_id, invoice_id)
```

A NFE.io expõe **vários subdomínios** (api.nfe.io, api.nfse.io, address.api.nfe.io, etc.). O roteamento de host é uma decisão de primeira classe: vive **só** na `Configuration` (host map), e nenhum recurso hard-coda URL. O contrato de emissão assíncrona (HTTP 202 + `Location`) precisa de tipos de resultado discrimináveis (`Pending`/`Issued`) já na base, pois adicioná-los depois quebra assinaturas públicas.

Esta change **possui o registro de recursos**: entrega 17 acessores stub que as changes de recurso preenchem depois. A decisão central é o conjunto de idiomas Ruby que diferem de PHP/Node: `Data.define` para objetos de valor imutáveis, keyword args, `snake_case`, `Net::HTTP`, módulos, `raise` de erros tipados, downloads como `String` binária, e retornos síncronos (sem Promises/Futures).

## Goals / Non-Goals

**Goals**

- `Nfe::Client.new(api_key: "...")` funciona com defaults sensatos (produção, retries default, transporte `Net::HTTP` default).
- 17 acessores lazy snake_case memoizados na primeira leitura, paridade-plus com o SDK PHP.
- `Nfe::Configuration` tipada, validada no `initialize`.
- Host map multi-base-URL como **fonte única de verdade** com resolução por família e fallback `main`.
- `AbstractResource` cobre o CRUD plano via helpers (`get`/`post`/`put`/`delete`), `hydrate`, `download`, `hydrate_list`.
- `IdValidator` fail-fast em pt-BR antes de qualquer chamada HTTP.
- Contrato 202 discriminado (`Pending`/`Issued`) e `FlowStatus.terminal?` entregues agora.
- `ListResponse`/`ListPage` cobrindo paginação page-style e cursor-style.
- Tudo testável com transporte mock injetado via `Configuration`.

**Non-Goals**

- `create_and_wait` / `poll_until_complete` — diferido pós-1.0 (paridade com decisão de PHP/Node). `FlowStatus.terminal?` já habilita loop manual.
- `create_batch` — açúcar concorrente; sem ganho real no modelo síncrono v1.
- Implementação concreta de qualquer recurso (vem nas changes de recurso).
- Downloads em streaming — retornamos `String` completa (binary-safe). Arquivos muito grandes ficam para release futura.
- Validação de dígito verificador de CNPJ/CPF além de formato/normalização — a API valida no servidor; o validador local é fail-fast para typos, não substituto.
- Hot-swap de transporte em runtime — config é resolvida na construção.

## Decisions

### D1. Cliente único com acessores lazy memoizados (não eager)

**Decisão**: `Nfe::Client` expõe 17 métodos acessores snake_case. Cada um memoiza a instância do recurso na primeira leitura (`@service_invoices ||= ServiceInvoicesResource.new(self)`).

**Por quê**:
- Paridade com o lazy-init do SDK Node (`NfeClient` cria recursos e clientes HTTP sob demanda) — um cliente só com `data_api_key` funciona para recursos de dados sem nunca tocar (e validar) a chave principal.
- Em Ruby, expor método acessor (não atributo público gravável) é idiomático e mantém o objeto imutável por fora.
- A memoização evita realocar recursos a cada acesso sem o custo de construir 17 objetos no boot.

**Alternativa rejeitada**: binding eager de todos os recursos no `initialize` (como o SDK PHP). Funciona, mas força resolução de chave/transporte de famílias nunca usadas e perde a propriedade "cliente com só data_api_key é válido".

### D2. `Configuration` como objeto tipado, não Hash

**Decisão**: `Nfe::Configuration` com atributos nomeados, validado no `initialize`. `Nfe::Client.new` aceita ou keyword args de conveniência (que montam a `Configuration`) ou uma `configuration:` explícita.

```ruby
Nfe::Client.new(api_key: "k", timeout: 120)                 # atalho
Nfe::Client.new(configuration: Nfe::Configuration.new(...)) # controle total
```

**Por quê**: typos viram erro cedo; defaults explícitos na assinatura; validação centralizada. Hash de config é "Ruby-ish" mas perde checagem e autocomplete (Steep/RBS).

### D3. `environment` como Symbol (`:production`/`:development`), não string

**Decisão**: `environment:` aceita `:production` (default) ou `:development`. Valor inválido levanta `Nfe::ConfigurationError`.

**Por quê**: paridade com o Node (`validateAndNormalizeConfig` aceita só `production`/`development`). Ambos os ambientes usam o mesmo endpoint — a diferenciação é por **chave de API**, não por URL. Documentar isso evita a expectativa errada de "sandbox URL". (O Node às vezes diz "sandbox" no README, mas só valida production/development — não replicar a confusão.)

### D4. Host map é a fonte única de verdade na `Configuration`

**Decisão**: `Configuration#base_url_for(family)` é o **único** lugar que conhece hosts. Mapa confirmado (CANONICAL FACTS):

| Família | Host |
|---|---|
| `main` (companies, service invoices, legal/natural people, webhooks) | `https://api.nfe.io` |
| `addresses` | `https://address.api.nfe.io/v2` (o `/v2` é parte do host) |
| `nfe-query` (product/consumer invoice query) | `https://nfe.api.nfe.io` |
| `legal-entity` (lookup CNPJ) | `https://legalentity.api.nfe.io` |
| `natural-person` (lookup CPF) | `https://naturalperson.api.nfe.io` |
| `cte` (transportation, inbound product, tax calc/codes, product/consumer invoices, state taxes) | `https://api.nfse.io` |
| desconhecida | `https://api.nfe.io` (default seguro) |

Cada recurso declara sua família via `api_family` (ex.: `:cte`), nunca uma URL literal. Overrides por família via `base_url_overrides` na `Configuration` (escape hatch).

**Por quê**: centralizar elimina a classe de bug "recurso aponta para host errado → 404" (exatamente o bug que o SDK PHP teve de corrigir em c05, quando 6 famílias estavam mapeadas para hosts errados). Uma única tabela auditável, coberta por teste por família.

**Por quê da divergência de docs**: as deltas do SDK PHP listavam `api-legalentity.nfe.io`/`api-naturalperson.nfe.io`; o host autoritativo (Node + client-core PHP) é `*.api.nfe.io`. Usamos `legalentity.api.nfe.io` / `naturalperson.api.nfe.io`.

### D5. Resolução de chave por família (modelo de duas chaves)

**Decisão**: `Configuration#api_key_for(family)`. Famílias de dados (`addresses`, `legal-entity`, `natural-person`, `nfe-query`) usam `data_api_key` quando presente; caso contrário caem para `api_key`. Demais famílias usam `api_key`.

**Por quê**: a plataforma separa cobrança entre a API principal (emissão/companies/webhooks) e a API de dados (CEP/CNPJ/CPF/query). Espelha a cadeia `resolveDataApiKey` do Node (`dataApiKey ?? apiKey`). Um cliente só com chave principal continua funcionando para recursos de dados (fallback). As próprias chaves caem para `ENV` quando não passadas explicitamente (ver D17).

### D6. `AbstractResource` provê CRUD genérico + helpers

**Decisão**: base abstrata recebe o `Client` na construção e expõe (protected): `get`/`post`/`put`/`delete`, `full_path`, `hydrate`, `download`, `hydrate_list`, `handle_async_response`. Cada subclasse declara `api_family` e `api_version`.

```ruby
class AbstractResource
  def initialize(client) = @client = client
  protected
  def api_family  = raise NotImplementedError
  def api_version = "v1" # subclasses sobrescrevem; addresses retorna ""
  def get(path, query: {}, **opts) = request(:get, path, query: query, **opts)
  # post/put/delete análogos
  def full_path(path)
    # tolera api_version vazia (addresses) sem gerar "//addresses/x"
    version = api_version.to_s
    version.empty? ? path : "/#{version}#{path}"
  end
  def hydrate(klass, payload) = klass.from_api(payload) # Data.define value object
  def download(path, **opts)
    body = get(path, accept: "application/octet-stream", **opts).body
    body.dup.force_encoding(Encoding::ASCII_8BIT)
  end
end
```

**Por quê**: ~80% dos endpoints são CRUD plano; helpers eliminam boilerplate. `full_path` precisa tolerar `api_version` vazia porque o host de `addresses` já embute `/v2`.

### D7. `hydrate` materializa DTOs `Data.define` imutáveis

**Decisão**: `hydrate(klass, payload)` chama um construtor de fábrica do DTO gerado (ex.: `klass.from_api(hash)`), produzindo um objeto de valor `Data.define` imutável de **add-openapi-pipeline**. O desempacotamento de envelope (`{"serviceInvoice" => {...}}`) é feito **no recurso** (cada endpoint conhece seu wrapper), não na base.

**Por quê**: `Data.define` é o idioma Ruby 3.2+ para objetos de valor imutáveis — equivalente aos `readonly`/`Data` do PHP e às interfaces TS. Wrappers variam por endpoint; centralizar viraria chuva de `if`.

**Alternativa rejeitada**: `OpenStruct`/Hash cru — perde imutabilidade, tipo e autocomplete via RBS.

### D8. Downloads retornam `String` binary-safe (ASCII-8BIT)

**Decisão**: `download(path)` retorna `String` com bytes crus, com `force_encoding(Encoding::ASCII_8BIT)`. O chamador decide se persiste (`File.binwrite`) ou faz streaming.

**Por quê**: Ruby não tem `Buffer` (Node) nem decisão de "string binary-safe" implícita (PHP). Forçar ASCII-8BIT garante que PDFs/XMLs/ZIPs não sejam corrompidos por transcodificação UTF-8. Mapeia `Buffer` (Node) e `string` (PHP) para o idioma Ruby correto.

**Nota de divergência (foldada nas changes de recurso)**: downloads de `product_invoices` retornam um `NfeFileResource` (URI), **não** bytes — ao contrário de service/query/inbound. O helper `download` aqui serve aos que retornam bytes; recursos URI-resource usam `get` + `hydrate` normal.

### D9. Contrato 202 discriminado: `Pending` / `Issued`

**Decisão**: dois tipos base de resultado em `lib/nfe/results.rb`:

```ruby
module Nfe
  # 202 + Location: emissão assíncrona pendente
  Pending = Data.define(:invoice_id, :location)
  # 201 + body: emissão materializada
  Issued  = Data.define(:resource)
end
```

Recursos que podem retornar 202 retornam `Pending` ou `Issued`; o consumidor discrimina com `case result when Nfe::Pending` / `result.is_a?(Nfe::Pending)`. `handle_async_response` na base extrai o `invoice_id` do header `Location` (regex `%r{/([a-z0-9-]+)\z}i` sobre o último segmento), levantando `Nfe::InvoiceProcessingError` se 202 vier sem `Location`.

**Por quê**: o consumidor escreve `if result.is_a?(Nfe::Pending)` em vez de inspecionar `status`. `Data.define` dá igualdade por valor, imutabilidade e `to_h` de graça. Refatorar isso depois seria breaking change — por isso entra agora, mesmo sem polling.

**Por quê tipos base genéricos (não por família)**: o registro de recursos (esta change) só precisa do contrato base. As changes de recurso podem subclassificar (`ServiceInvoicePending < Nfe::Pending`?) se precisarem de `instanceof` mais fino, mas o piso é o par genérico `Pending`/`Issued`.

### D10. `FlowStatus.terminal?` agora; polling diferido

**Decisão**: `Nfe::FlowStatus.terminal?(status)` retorna `true` para exatamente `"Issued"`, `"IssueFailed"`, `"Cancelled"`, `"CancelFailed"` (cravado em `client-nodejs/src/core/types.ts`). NÃO entregar `create_and_wait`/`poll_until_complete` em 1.0.

**Por quê**: paridade com a decisão de PHP/Node de diferir polling. O contrato discriminado + `terminal?` bastam para um loop de polling manual:

```ruby
result = client.service_invoices.create(company_id, data)
if result.is_a?(Nfe::Pending)
  loop do
    sleep 2
    invoice = client.service_invoices.retrieve(company_id, result.invoice_id)
    break invoice if Nfe::FlowStatus.terminal?(invoice.flow_status)
  end
end
```

Quando o helper de polling chegar (release futura), `terminal?` já está pronto para ser consumido — sem breaking change.

### D11. `ListResponse`/`ListPage` cobrem dois shapes de paginação

**Decisão**: `Nfe::ListResponse` carrega `data` (lista de DTOs) + `page` (`Nfe::ListPage`). `ListPage` expõe `page_index`, `page_count`, `starting_after`, `ending_before`, `total` — todos opcionais. O recurso preenche a metade relevante ao seu endpoint.

```ruby
ListResponse = Data.define(:data, :page)
ListPage     = Data.define(:page_index, :page_count, :starting_after, :ending_before, :total)
```

`hydrate_list(klass, payload, wrapper_key:)` desempacota `{wrapper_key => [...]}`, hidrata cada item e detecta o shape de página.

**Por quê**: a API usa page-style (`page_index`/`page_count` — service invoices, companies, tax codes) **e** cursor-style (`starting_after`/`ending_before` — product/consumer invoices, state taxes) no mesmo SDK. Um único tipo, com metades opcionais, mantém `result.data` idêntico nos dois casos. Dois tipos separados seriam "mais corretos" mas forçariam o chamador a discriminar.

### D12. `IdValidator` fail-fast em pt-BR

**Decisão**: módulo `Nfe::IdValidator` com métodos `company_id`, `invoice_id`, `access_key`, `state_tax_id`, `event_key`, `cnpj`, `cpf`, `cep`, `state`. Cada método valida (e quando aplicável normaliza) e levanta `Nfe::InvalidRequestError` com mensagem em português antes de qualquer HTTP.

- `access_key`: aceita entrada formatada (espaços/pontos/hífens), remove não-dígitos, valida `/^\d{44}$/`, retorna a string normalizada.
- `cnpj`/`cpf`: normalizam para 14/11 dígitos (formato; sem dígito verificador). **Nota v3**: a partir de jul/2026 o CNPJ pode ser alfanumérico nos endpoints v3 — `cnpj` NÃO deve coagir para Integer (gap a evitar; o `validateCNPJ` do Node assume numérico).
- `cep`: normaliza removendo hífen, valida 8 dígitos.
- `state`: UF maiúscula (27 + `EX`/`NA`).

**Por quê**: paridade com os validadores do Node (`validateCompanyId`, `validateAccessKey`, etc.). Fail-fast com mensagem clara em português alinha com a audiência (NFE.io é Brasil).

### D13. `Nfe::Client` é a classe pública final; customização por composição

**Decisão**: customização do comportamento é via transporte/`Configuration` injetáveis, não via subclasse do `Client`.

**Por quê**: composição > herança. Testes usam transporte mock (de add-http-transport), não subclasse. Mantém a superfície pública estreita e estável.

### D14. `Nfe::VERSION` em arquivo dedicado

**Decisão**: `lib/nfe/version.rb` com `Nfe::VERSION = "1.0.0"`. O transporte lê esse valor ao montar `User-Agent` (com `user_agent_suffix` opcional anexado).

**Por quê**: convenção de gem Ruby (`lib/<gem>/version.rb`); sem IO no boot; o `*.gemspec` lê a constante. Bump 0.3.2 → 1.0.0 conforme decisão canônica.

### D15. Acessores memoizados são thread-safe (Mutex)

**Decisão**: a memoização lazy dos 17 acessores no `Client` é guardada por um `Mutex` (`@resource_mutex.synchronize { @x ||= ... }`), de modo que um único `Client` compartilhado entre threads é seguro (Rails/Sidekiq/Puma). O pool de conexões keep-alive por origem é guardado por seu próprio `Mutex` em **add-http-transport**.

**Por quê**: o padrão de uso real é um `Client` global compartilhado por workers concorrentes. Sem o Mutex, duas threads na primeira leitura do mesmo acessor podem construir o recurso duas vezes (race benigna em estrutura, mas evitável e barata). Não é Open Question — é requisito.

### D16. `RequestOptions` para opções por chamada (multi-tenant)

**Decisão**: `Nfe::RequestOptions = Data.define(:api_key, :base_url, :timeout)` (campos opcionais). `Client#request` aceita `request_options:`; campos não-nil sobrepõem a resolução da família por chamada, nil cai para a resolução normal. `AbstractResource` repassa `request_options:` nos helpers; métodos de emissão o aceitam.

**Por quê**: integradores multi-tenant precisam de uma `api_key` por chamada sem alocar um `Client` por tenant. `Data.define` mantém o objeto imutável e seguro para compartilhar.

### D17. Chaves caem para variáveis de ambiente (fallback)

**Decisão**: `api_key`/`data_api_key` caem para `ENV["NFE_API_KEY"]`/`ENV["NFE_DATA_API_KEY"]` quando o arg explícito for nil (ordem: arg explícito || env). A validação "ao menos uma chave" roda após o fallback.

**Por quê**: convenção de 12-factor; `Nfe::Client.new` sem args funciona em ambientes com as env vars setadas, sem vazar a chave para o código.

### D18. Confiança TLS só ADICIONA; nunca desliga verificação

**Decisão**: `Configuration#ca_file` (e opcionalmente `#ca_path`) é o ÚNICO override de confiança TLS e só ADICIONA/substitui um CA bundle. NÃO há API pública para `VERIFY_NONE`/`insecure_ssl` — a verificação de peer nunca pode ser desligada. `#proxy` é repassado ao `Net::HTTP`.

**Por quê**: ambientes corporativos exigem CA bundle próprio (proxy de inspeção), mas desligar verificação é um risco que o SDK não deve expor. O `insecureSsl` upstream é atributo server-side do alvo de webhook, não a TLS de saída do SDK — não confundir.

## Risks / Trade-offs

| Risco | Mitigação |
|---|---|
| Host map errado derruba múltiplos recursos com 404 (foi exatamente o bug de c05 no SDK PHP) | Tabela única auditável em `Configuration#base_url_for`; teste por família (6 hosts) obrigatório; nenhum recurso hard-coda URL |
| Refatorar o contrato 202 (`Pending`/`Issued`) depois é breaking change | Definir o par `Pending`/`Issued` + `handle_async_response` agora, na base, antes de qualquer recurso concreto |
| Shapes de paginação variam por endpoint (page vs cursor) | `ListPage` com metades opcionais acomoda ambos; cada `list()` documenta qual metade preenche |
| DTOs gerados podem não cobrir o shape real de algumas respostas (gen cobre `components.schemas`) | Changes de recurso criam DTOs hand-written fora de `lib/nfe/generated/` quando preciso; `hydrate` aceita qualquer `klass` com `.from_api` |
| Stubs vazios dos 17 recursos enganam o consumidor antes das changes de recurso | Cada stub levanta `NotImplementedError` com nome da change que o preenche |
| `regex` de `access_key` (44 dígitos) é frouxa e aceita sequências inválidas | Aceitar — validação local é fail-fast para typo, não substitui validação server-side |
| Cliente só com `data_api_key` não deve falhar na construção | Resolução de chave é lazy (no acesso ao recurso/transporte da família), não no `initialize` |
| Ausência de `create_and_wait` frustra quem espera polling automático | README documenta loop manual com `is_a?(Nfe::Pending)` + `FlowStatus.terminal?`; helper vem em release futura sem breaking change |
| CNPJ alfanumérico (v3, jul/2026) quebra coerção numérica | `IdValidator.cnpj` valida formato sem coagir para Integer; documentar que endpoints v3 aceitam alfanumérico |
