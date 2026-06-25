# add-client-core

## Why

O SDK Ruby v1 (gem `nfe-io`, bump 0.3.2 → 1.0.0, reescrita greenfield) é montado em camadas:

- **add-ruby-foundation** entrega o terreno: namespace `Nfe`, layout `lib/nfe/`, piso Ruby 3.2, `# frozen_string_literal: true` em todo `.rb`, RuboCop/Steep/RSpec/SimpleCov, zero dependências de runtime (só stdlib).
- **add-http-transport** entrega a camada HTTP testável sobre `Net::HTTP`: request/response, retries com backoff, timeouts, hierarquia de erros tipados (`Nfe::Error` e filhos) e injeção de transporte para teste.
- **add-openapi-pipeline** entrega o gerador: specs OpenAPI sincronizadas de `nfeio-docs` → objetos de valor imutáveis `Data.define` em `lib/nfe/generated/` + assinaturas `.rbs` em `sig/`.

Falta a **superfície pública** que amarra tudo e que o consumidor de fato usa: o objeto `Nfe::Client` instanciável, no estilo Stripe (cliente único + acessores de recurso), a configuração tipada, o **host map multi-base-URL como fonte única de verdade**, a base `AbstractResource` que cobre ~80% dos endpoints CRUD com helpers, e o **contrato 202 discriminado** (Pending/Issued) que precisa existir na base antes de qualquer recurso concreto — adicioná-lo depois seria breaking change.

Esta change é o núcleo de DX feito à mão. Ela **possui o registro de recursos**: entrega os **17 acessores stub lazy** que as changes de recurso (entity/invoice/lookup/rtc) depois preenchem. Sem ela, as três camadas anteriores são infraestrutura abstrata; com ela fechada, o SDK é exercitável internamente (dogfooding) mesmo antes de qualquer recurso concreto, porque a `AbstractResource` já contém o CRUD genérico.

Depende de **add-ruby-foundation**, **add-http-transport** e **add-openapi-pipeline** (todas pré-requisitos).

## What Changes

### `Nfe::Client` — entrypoint único estilo Stripe

- `Nfe::Client.new(api_key: "...", **config)` — cliente único com **17 acessores lazy snake_case** de recurso, memoizados na primeira leitura.
- Acessores são snake_case (`client.service_invoices`, `client.legal_entity_lookup`), paridade-plus com o SDK PHP (mesma superfície de 17 recursos).
- Cada acessor cria seu recurso preguiçosamente passando o transporte já resolvido para a família de host correta.
- `Nfe::Client` é a classe final pública; customização é por composição (transporte/config injetáveis), não herança.
- Os acessores memoizados são guardados por `Mutex` — um `Client` compartilhado é thread-safe (Rails/Sidekiq/Puma).
- `Nfe::RequestOptions` (`api_key`/`base_url`/`timeout`, opcionais) permite sobrepor a resolução por chamada — `api_key` por tenant sem um segundo `Client`.

### `Nfe::Configuration` — config tipada

- `api_key`, `data_api_key` (fallback para `api_key`), `environment` (`:production` | `:development`, default `:production`), `timeout`, `open_timeout`, `max_retries`, `logger`, `user_agent_suffix`, `ca_file`/`ca_path` (override de confiança TLS — só ADICIONA CA, nunca desliga verificação), `proxy`.
- `api_key`/`data_api_key` caem para `NFE_API_KEY`/`NFE_DATA_API_KEY` do ambiente como fallback; arg explícito vence.
- Overrides de base-URL por família (escape hatch para apontar para hosts customizados/sandbox).
- Validação no `initialize` (api_key não vazia, environment válido) levantando `Nfe::ConfigurationError`.

### Host map multi-base-URL — fonte única de verdade

- `Nfe::Configuration#base_url_for(family)` resolve o host correto por família de produto NFE.io. **Nenhum recurso hard-coda URL.**
- Mapa confirmado (CANONICAL FACTS): `main → https://api.nfe.io`; `addresses → https://address.api.nfe.io/v2`; `nfe-query → https://nfe.api.nfe.io`; `legal-entity → https://legalentity.api.nfe.io`; `natural-person → https://naturalperson.api.nfe.io`; `cte → https://api.nfse.io`. Família desconhecida → `main` como default seguro.
- Resolução da chave de API por família (chave de dados para `addresses`/`legal-entity`/`natural-person`/`nfe-query`, com fallback para a chave principal).

### `Nfe::Resources::AbstractResource` — base de recurso

- Helpers `get`/`post`/`put`/`delete` que delegam ao transporte com base-URL e versão da família.
- `full_path` tolerando versão de API vazia (caso `addresses`, cujo `/v2` está embutido no host).
- `hydrate(klass, payload)` para materializar DTOs `Data.define` gerados.
- `download(path)` retornando bytes crus como `String` binary-safe (`force_encoding("ASCII-8BIT")`).
- `hydrate_list` produzindo `Nfe::ListResponse` + `Nfe::ListPage` que cobre paginação **page-style** (`page_index`/`page_count`) **e** cursor-style (`starting_after`/`ending_before`).
- `Nfe::IdValidator` (`company_id`, `invoice_id`, `access_key` normalizando para `/^\d{44}$/`, `state_tax_id`, `event_key`, `cnpj`, `cpf`, `cep`, `state`) levantando `Nfe::InvalidRequestError` fail-fast com mensagens em pt-BR.

### Contrato 202 discriminado + FlowStatus

- Tipos base de resultado: `Nfe::Pending` (expõe `invoice_id`/`location`) e `Nfe::Issued` (expõe `resource`). Recursos que podem retornar 202 retornam um dos dois, discriminável por classe.
- `Nfe::FlowStatus.terminal?(status)` retornando `true` para `Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`.

### Diferido explicitamente (pós-1.0)

- `create_and_wait` / helper de polling (`poll_until_complete`) — paridade com a decisão de PHP/Node de diferir. `Nfe::FlowStatus.terminal?` já é entregue agora para habilitar loops de polling manuais.
- `create_batch` — açúcar concorrente, sem ganho real no modelo síncrono v1.

## Capabilities

### New Capabilities

- `client-core`: classe `Nfe::Client` com 17 acessores lazy snake_case; `Nfe::Configuration` tipada; host map multi-base-URL como fonte única de verdade; `Nfe::Resources::AbstractResource` com helpers (get/post/put/delete, full_path, hydrate, download, hydrate_list); `Nfe::IdValidator`; tipos base do contrato 202 (`Pending`/`Issued`); `Nfe::ListResponse`/`Nfe::ListPage`; `Nfe::FlowStatus.terminal?`.

### Modified Capabilities

- (nenhuma — greenfield)

## Impact

- **Código afetado**: `lib/nfe/client.rb`, `lib/nfe/configuration.rb`, `lib/nfe/request_options.rb` (`RequestOptions`), `lib/nfe/resources/abstract_resource.rb`, `lib/nfe/id_validator.rb`, `lib/nfe/pagination.rb` (`ListResponse`/`ListPage`), `lib/nfe/results.rb` (`Pending`/`Issued`), `lib/nfe/flow_status.rb`, `lib/nfe/version.rb`, e 17 stubs de recurso UNSUFFIXED em `lib/nfe/resources/<resource>.rb` (`Nfe::Resources::<CamelResource>`). Assinaturas correspondentes em `sig/`.
- **Spec impact**: adiciona a capability `client-core`.
- **Dependências**: depende de **add-ruby-foundation** (namespace/tooling), **add-http-transport** (transporte + erros) e **add-openapi-pipeline** (DTOs `Data.define` para `hydrate`).
- **Downstream**: as changes de recurso (entity/invoice/lookup/rtc) substituem os 17 stubs por implementações reais reaproveitando `AbstractResource`, `IdValidator`, `ListResponse`, `Pending`/`Issued` e o host map daqui.
- **Riscos**:
  - O contrato 202 (`Pending`/`Issued`) precisa estar correto agora — refatorá-lo depois é breaking change.
  - Shapes de paginação variam por endpoint (page vs cursor); `ListPage` acomoda ambos.
  - O host map é a única fonte de verdade — um erro aqui derruba múltiplos recursos com 404; cobertura de teste por família é obrigatória.
