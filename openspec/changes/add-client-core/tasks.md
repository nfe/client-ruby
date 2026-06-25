# Tasks — add-client-core

> Greenfield. Todos os itens UNCHECKED. Depende de **add-ruby-foundation** (namespace `Nfe`, layout `lib/nfe/`, tooling), **add-http-transport** (transporte `Net::HTTP`, retries, erros tipados) e **add-openapi-pipeline** (DTOs `Data.define` + `.rbs`). Todo `.rb` começa com `# frozen_string_literal: true`. Ruby floor 3.2; CI 3.2/3.3/3.4. Zero dependências de runtime (só stdlib). Tipos via RBS em `sig/`, Steep no CI, RuboCop no lint, RSpec com SimpleCov >= 80%.

## 1. Versão e constantes

- [ ] 1.1 Criar `lib/nfe/version.rb` com `module Nfe; VERSION = "1.0.0"; end` (bump 0.3.2 → 1.0.0).
- [ ] 1.2 `*.gemspec` lê `Nfe::VERSION` (carregar o arquivo no gemspec; sem hardcode duplicado).
- [ ] 1.3 Assinatura `sig/nfe/version.rbs` (`Nfe::VERSION: String`).
- [ ] 1.4 Spec `spec/nfe/version_spec.rb` — `Nfe::VERSION` casa com `/\A\d+\.\d+\.\d+/`.

## 2. Erros do core (estendendo a hierarquia de add-http-transport)

- [ ] 2.1 Garantir `Nfe::ConfigurationError < Nfe::Error` (config inválida: api_key faltando para uma família, environment inválido). Se já existir em add-http-transport, apenas referenciar; senão definir em `lib/nfe/errors.rb`.
- [ ] 2.2 Garantir `Nfe::InvalidRequestError < Nfe::Error` (validação client-side: id vazio, access_key malformada, etc.) — mensagens em pt-BR.
- [ ] 2.3 Garantir `Nfe::InvoiceProcessingError < Nfe::Error` (202 sem `Location`, invoice_id não extraível).
- [ ] 2.4 Assinaturas `sig/` para quaisquer erros novos introduzidos aqui.
- [ ] 2.5 Spec `spec/nfe/errors_spec.rb` cobrindo herança e `message`/`code`/`status` dos erros novos.

## 3. Configuration + host map (fonte única de verdade)

- [ ] 3.1 Criar `lib/nfe/configuration.rb` — `Nfe::Configuration` com `api_key`, `data_api_key`, `environment` (default `:production`), `timeout` (default 30), `open_timeout`, `max_retries` (default 3), `logger`, `user_agent_suffix`, `base_url_overrides` (Hash família→URL), `ca_file` (default nil), `ca_path` (opcional, default nil) e `proxy` (default nil).
- [ ] 3.2 Validar no `initialize`: `api_key` não vazia (a menos que só `data_api_key` seja fornecida — ver 3.3); `environment` ∈ `{:production, :development}` senão `raise Nfe::ConfigurationError`; `timeout`/`open_timeout` positivos.
- [ ] 3.3 Permitir cliente só com `data_api_key` (resolução de chave principal é lazy, não no `initialize`). Validar que ao menos uma chave foi fornecida (após aplicar o fallback de ENV da 3.8).
- [ ] 3.4 Implementar `#base_url_for(family)` com o mapa confirmado: `main → https://api.nfe.io`; `addresses → https://address.api.nfe.io/v2`; `nfe-query → https://nfe.api.nfe.io`; `legal-entity → https://legalentity.api.nfe.io`; `natural-person → https://naturalperson.api.nfe.io`; `cte → https://api.nfse.io`; default (desconhecida) → `main`. Aceitar aliases de família (ex.: `:companies`, `:service_invoices` → `main`; `:transportation`, `:inbound_product`, `:tax_calculation`, `:tax_codes`, `:product_invoices`, `:consumer_invoices`, `:state_taxes` → `cte`).
- [ ] 3.5 `#base_url_for` consulta `base_url_overrides[family]` primeiro (escape hatch); só então aplica o mapa.
- [ ] 3.6 Implementar `#api_key_for(family)` — famílias de dados (`:addresses`, `:legal_entity`, `:natural_person`, `:nfe_query`) usam `data_api_key` quando presente, senão `api_key`; demais usam `api_key`. Levantar `Nfe::ConfigurationError` se a chave resolvida for nil quando o recurso é acessado.
- [ ] 3.7 Documentar (comentário): produção e desenvolvimento usam o MESMO endpoint, diferenciados por chave (não por URL). Não expor "sandbox URL".
- [ ] 3.8 Resolução de chaves a partir do ambiente como FALLBACK: `api_key` cai para `ENV["NFE_API_KEY"]` e `data_api_key` cai para `ENV["NFE_DATA_API_KEY"]` quando o arg explícito for nil/ausente (ordem: arg explícito || env). Args explícitos sempre vencem. Aplicar antes da validação de "ao menos uma chave fornecida".
- [ ] 3.9 TLS-trust: `ca_file` (e opcionalmente `ca_path`) é o ÚNICO override de confiança TLS e só pode ADICIONAR/substituir um CA bundle. NÃO expor API pública para `VERIFY_NONE`/`insecure_ssl` (a verificação de peer NUNCA pode ser desligada). Comentar que o `insecureSsl` upstream é atributo server-side do alvo de webhook, não a TLS de saída do SDK. `proxy` é repassado ao `Net::HTTP` (stdlib).
- [ ] 3.10 Assinatura `sig/nfe/configuration.rbs` (incluir `ca_file`, `ca_path`, `proxy`).
- [ ] 3.11 Spec `spec/nfe/configuration_spec.rb`: defaults; api_key vazia → erro; environment inválido → erro; só `data_api_key` constrói; `base_url_for` para as 6 famílias + default + override; `api_key_for` fallback data→main; env fallback `NFE_API_KEY`/`NFE_DATA_API_KEY` com arg explícito vencendo; nenhuma API pública desliga a verificação de peer.

## 4. Client (entrypoint + 17 acessores lazy)

- [ ] 4.1 Criar `lib/nfe/client.rb` — `Nfe::Client.new(api_key: nil, data_api_key: nil, configuration: nil, environment: :production, timeout: 30, max_retries: 3, logger: nil, user_agent_suffix: nil)`. Se `configuration:` vier, ignora os outros; senão monta `Configuration` a partir deles.
- [ ] 4.2 Expor `attr_reader :configuration` (e o transporte resolvido). Cliente é a classe pública final; sem subclasse suportada.
- [ ] 4.3 Implementar resolução/memoização de transporte por família (chama add-http-transport com `base_url_for(family)`, `api_key_for(family)`, timeout, retries, user-agent). Memoizar por família.
- [ ] 4.4 Implementar os **17 acessores lazy snake_case**, cada um memoizado sob Mutex (ex.: `@mutex.synchronize { @service_invoices ||= Nfe::Resources::ServiceInvoices.new(self) }`) e referenciando as classes UNSUFFIXED `Nfe::Resources::<CamelResource>`: `service_invoices`, `product_invoices`, `consumer_invoices`, `transportation_invoices`, `inbound_product_invoices`, `product_invoice_query`, `consumer_invoice_query`, `companies`, `legal_people`, `natural_people`, `webhooks`, `addresses`, `legal_entity_lookup`, `natural_person_lookup`, `tax_calculation`, `tax_codes`, `state_taxes`.
- [ ] 4.5 Método interno `#request(method, family:, path:, query: {}, body: nil, headers: {}, request_options: nil)` (escape hatch low-level) que resolve transporte da família e injeta auth/user-agent; quando `request_options` vier, sobrepõe api_key/base_url/timeout por chamada (ver 4b). Marcar como `@api private` no comentário.
- [ ] 4.6 Acessar um recurso de família de dados com só `data_api_key` funciona; acessar um recurso `main` sem `api_key` levanta `Nfe::ConfigurationError` no momento do acesso.
- [ ] 4.7 Assinatura `sig/nfe/client.rbs` (17 acessores tipados aos seus `*Resource`).
- [ ] 4.8 Spec `spec/nfe/client_spec.rb`: construção via api_key e via configuration; 17 acessores retornam a classe certa; memoização (mesma instância em 2 leituras); só data_api_key funciona para data, falha para main; user-agent inclui versão + suffix.
- [ ] 4.9 Thread-safety: o `Client` guarda os acessores memoizados com um `Mutex` (`@resource_mutex.synchronize { ... }`), de modo que um `Client` compartilhado entre threads (Rails/Sidekiq/Puma) construa cada recurso uma única vez sem race. (O pool de conexões keep-alive é guardado em add-http-transport.)
- [ ] 4.10 Spec: leitura concorrente de um acessor por N threads retorna sempre a MESMA instância (sem duplicação por race).

## 4b. RequestOptions (opções por chamada / multi-tenant)

- [ ] 4b.1 Criar `lib/nfe/request_options.rb` — `Nfe::RequestOptions = Data.define(:api_key, :base_url, :timeout)` (todos opcionais, default nil), objeto de valor imutável para sobrepor configuração por chamada.
- [ ] 4b.2 `Nfe::Client#request` aceita `request_options:` (opcional) e, quando presente, sobrepõe `api_key`/`base_url`/`timeout` resolvidos da família por chamada — habilita `api_key` por tenant SEM um segundo `Client`. Args não preenchidos no `RequestOptions` caem para a resolução normal da família.
- [ ] 4b.3 `Nfe::Resources::AbstractResource` aceita e repassa um `request_options:` opcional nos helpers (`get`/`post`/`put`/`delete`) até `client.request`; métodos de recurso (ao menos os de emissão) aceitam `request_options:`.
- [ ] 4b.4 Assinatura `sig/nfe/request_options.rbs`.
- [ ] 4b.5 Spec `spec/nfe/request_options_spec.rb`: `RequestOptions` por chamada sobrepõe a `api_key` da família; campos nil caem para a resolução normal; dois tenants no mesmo `Client` usam chaves distintas por chamada.

## 5. Tipos base do contrato 202 (Pending / Issued)

- [ ] 5.1 Criar `lib/nfe/results.rb` — `Nfe::Pending = Data.define(:invoice_id, :location)` e `Nfe::Issued = Data.define(:resource)`.
- [ ] 5.2 (Opcional, doc) Marcar `Pending`/`Issued` como o piso discriminável; changes de recurso podem subclassificar se precisarem de discriminação mais fina.
- [ ] 5.3 Assinatura `sig/nfe/results.rbs`.
- [ ] 5.4 Spec `spec/nfe/results_spec.rb`: `Pending` expõe `invoice_id`/`location`; `Issued` expõe `resource`; igualdade por valor; `is_a?` discrimina.

## 6. FlowStatus

- [ ] 6.1 Criar `lib/nfe/flow_status.rb` — `Nfe::FlowStatus.terminal?(status)` retorna `true` para `"Issued"`, `"IssueFailed"`, `"Cancelled"`, `"CancelFailed"`; `false` para os demais (`PullFromCityHall`, `WaitingCalculateTaxes`, `WaitingDefineRpsNumber`, `WaitingSend`, `WaitingSendCancel`, `WaitingReturn`, `WaitingDownload`).
- [ ] 6.2 Aceitar `String` e Symbol (normalizar para comparação). Definir constantes `TERMINAL` e `NON_TERMINAL` (arrays congelados).
- [ ] 6.3 Assinatura `sig/nfe/flow_status.rbs`.
- [ ] 6.4 Spec `spec/nfe/flow_status_spec.rb`: os 4 terminais → true; os 7 não-terminais → false; valor desconhecido → false.

## 7. Paginação (ListResponse + ListPage)

- [ ] 7.1 Criar `lib/nfe/pagination.rb` — `Nfe::ListResponse = Data.define(:data, :page)` e `Nfe::ListPage = Data.define(:page_index, :page_count, :starting_after, :ending_before, :total)` (todos opcionais, default nil).
- [ ] 7.2 `ListResponse` permite iterar `result.data` igual nos dois shapes; `ListPage` carrega só a metade relevante.
- [ ] 7.3 (Opcional) helper `ListPage.from_page(index:, count:, total: nil)` e `ListPage.from_cursor(starting_after:, ending_before:, total: nil)` para conveniência dos recursos.
- [ ] 7.4 Assinatura `sig/nfe/pagination.rbs`.
- [ ] 7.5 Spec `spec/nfe/pagination_spec.rb`: page-style preenche page_index/page_count e cursores nil; cursor-style preenche cursores e page_index nil; `data` íntegro nos dois.

## 8. IdValidator (fail-fast em pt-BR)

- [ ] 8.1 Criar `lib/nfe/id_validator.rb` — módulo `Nfe::IdValidator` com métodos: `company_id(v)`, `invoice_id(v)`, `state_tax_id(v)`, `event_key(v)` (não vazios; retornam o valor).
- [ ] 8.2 `access_key(v)` — remove não-dígitos, valida `/\A\d{44}\z/`, retorna string normalizada; senão `Nfe::InvalidRequestError` ("chave de acesso deve conter 44 dígitos").
- [ ] 8.3 `cnpj(v)` — normaliza removendo separadores, valida formato (14 posições). NÃO coagir para Integer (suporte futuro a CNPJ alfanumérico v3). Retorna string normalizada.
- [ ] 8.4 `cpf(v)` — normaliza para 11 dígitos, valida formato. Retorna string normalizada.
- [ ] 8.5 `cep(v)` — remove hífen, valida 8 dígitos. Retorna string normalizada.
- [ ] 8.6 `state(v)` — UF maiúscula; valida contra lista (27 UFs + `EX`, `NA`). Retorna normalizada.
- [ ] 8.7 Todas as mensagens de erro em pt-BR, identificando qual argumento é inválido.
- [ ] 8.8 Assinatura `sig/nfe/id_validator.rbs`.
- [ ] 8.9 Spec `spec/nfe/id_validator_spec.rb`: company_id vazio → erro; access_key com separadores → 44 dígitos; access_key "123" → erro; cnpj/cpf/cep normalizam; state inválida → erro; cnpj alfanumérico não vira Integer.

## 9. AbstractResource (base + helpers)

- [ ] 9.1 Criar `lib/nfe/resources/abstract_resource.rb` — `Nfe::Resources::AbstractResource` recebe `client` no `initialize`; guarda referência.
- [ ] 9.2 `api_family` e `api_version` como métodos protected (subclasse sobrescreve; `api_version` default `"v1"`; `addresses` retorna `""`).
- [ ] 9.3 Helpers protected `get(path, query: {}, request_options: nil, **opts)`, `post(path, body: nil, request_options: nil, **opts)`, `put(path, body: nil, request_options: nil, **opts)`, `delete(path, query: {}, request_options: nil, **opts)` — delegam a `client.request(family:, path: full_path(path), request_options:, ...)`, repassando o `request_options` por chamada.
- [ ] 9.4 `full_path(path)` — prefixa `/#{api_version}` quando `api_version` não vazio; quando vazio (addresses) retorna `path` sem `//` duplicado.
- [ ] 9.5 `hydrate(klass, payload)` — materializa DTO `Data.define` chamando a fábrica `klass.from_api(payload)` do DTO gerado. O call site `from_api` fica aqui (client-core), mas o PRODUTOR de `from_api` (mapeamento camelCase→snake_case, drop de chaves desconhecidas, recursão em DTOs aninhados, `.rbs`) é **add-openapi-pipeline** — não redefinir `from_api` aqui. Desempacotamento de envelope fica no recurso, não na base.
- [ ] 9.6 `download(path, **opts)` — faz `get`, valida sucesso, retorna `response.body.dup.force_encoding(Encoding::ASCII_8BIT)` (bytes crus binary-safe). Define `Accept` apropriado quando o chamador passar (ex.: `application/pdf`).
- [ ] 9.7 `hydrate_list(klass, payload, wrapper_key:)` — desempacota `payload[wrapper_key]`, hidrata cada item em `klass`, monta `ListPage` detectando shape (page-style vs cursor-style) e retorna `Nfe::ListResponse`.
- [ ] 9.8 `handle_async_response(response, issued_klass:)` — se status 202: extrai `Location` (header, case-insensitive), parseia `invoice_id` do último segmento via `%r{/([a-z0-9-]+)\z}i`, retorna `Nfe::Pending`; sem `Location` → `Nfe::InvoiceProcessingError`. Se 201/200: hidrata `issued_klass` do body e retorna `Nfe::Issued`.
- [ ] 9.9 Assinatura `sig/nfe/resources/abstract_resource.rbs`.
- [ ] 9.10 Spec `spec/nfe/resources/abstract_resource_spec.rb` (via subclasse de teste + transporte mock): `full_path` com versão vazia e não-vazia; `get/post/put/delete` montam a request certa para a família; `download` retorna ASCII-8BIT; `hydrate_list` page e cursor; `handle_async_response` 202→Pending, 201→Issued, 202-sem-Location→InvoiceProcessingError.

## 10. Os 17 stubs de recurso (registro de recursos)

- [ ] 10.1 Criar 17 arquivos stub em `lib/nfe/resources/` na convenção UNSUFFIXED (`lib/nfe/resources/<resource>.rb` definindo `Nfe::Resources::<CamelResource>`), um por recurso, cada classe `< Nfe::Resources::AbstractResource` declarando seu `api_family` correto. Os nomes SÃO os UNSUFFIXED exatos para que as changes de recurso substituam os stubs arquivo-a-arquivo:
  - `service_invoices.rb` → `Nfe::Resources::ServiceInvoices` (`:main`), `product_invoices.rb` → `Nfe::Resources::ProductInvoices` (`:cte`), `consumer_invoices.rb` → `Nfe::Resources::ConsumerInvoices` (`:cte`), `transportation_invoices.rb` → `Nfe::Resources::TransportationInvoices` (`:cte`), `inbound_product_invoices.rb` → `Nfe::Resources::InboundProductInvoices` (`:cte`)
  - `product_invoice_query.rb` → `Nfe::Resources::ProductInvoiceQuery` (`:nfe_query`), `consumer_invoice_query.rb` → `Nfe::Resources::ConsumerInvoiceQuery` (`:nfe_query`)
  - `companies.rb` → `Nfe::Resources::Companies` (`:main`), `legal_people.rb` → `Nfe::Resources::LegalPeople` (`:main`), `natural_people.rb` → `Nfe::Resources::NaturalPeople` (`:main`), `webhooks.rb` → `Nfe::Resources::Webhooks` (`:main`)
  - `addresses.rb` → `Nfe::Resources::Addresses` (`:addresses`, `api_version` `""`), `legal_entity_lookup.rb` → `Nfe::Resources::LegalEntityLookup` (`:legal_entity`), `natural_person_lookup.rb` → `Nfe::Resources::NaturalPersonLookup` (`:natural_person`)
  - `tax_calculation.rb` → `Nfe::Resources::TaxCalculation` (`:cte`), `tax_codes.rb` → `Nfe::Resources::TaxCodes` (`:cte`), `state_taxes.rb` → `Nfe::Resources::StateTaxes` (`:cte`)
- [ ] 10.2 Cada stub declara `api_family`/`api_version` corretos mas NÃO implementa métodos de negócio — chamadas a métodos de negócio levantam `NotImplementedError` com a mensagem da change que o preenche (ex.: "implementado em add-invoice-resources").
- [ ] 10.3 Garantir que `client.<accessor>` retorna a instância stub correta e que sua família resolve o host esperado (sem 404 por host errado).
- [ ] 10.4 Assinaturas `sig/` para cada stub (classe + `api_family`).
- [ ] 10.5 Spec `spec/nfe/resources/registry_spec.rb`: para os 17 acessores, a família declarada mapeia para o host correto via `base_url_for`; cobre os 6 hosts distintos.

## 11. Require/boot

- [ ] 11.1 Garantir que `lib/nfe.rb` faz `require` de version, errors, configuration, request_options, results, flow_status, pagination, id_validator, abstract_resource, os 17 stubs UNSUFFIXED (`lib/nfe/resources/<resource>.rb`) e client (na ordem de dependência).
- [ ] 11.2 Confirmar que `require "nfe"` carrega tudo sem erro e que `Nfe::Client.new(api_key: "k")` instancia.

## 12. Documentação e exemplos

- [ ] 12.1 README: Quickstart com `Nfe::Client.new(api_key:)`, exemplo de acesso lazy a recurso, e tabela dos 17 acessores → família/host.
- [ ] 12.2 README: documentar o loop de polling MANUAL com `result.is_a?(Nfe::Pending)` + `Nfe::FlowStatus.terminal?`, com nota explícita de que `create_and_wait`/`poll_until_complete` são DIFERIDOS para release pós-1.0.
- [ ] 12.3 README: documentar modelo de duas chaves (`api_key` vs `data_api_key`) e quando cada família usa qual.
- [ ] 12.4 README: nota de que downloads retornam `String` binária (ASCII-8BIT) — usar `File.binwrite`.

## 13. Validação end-to-end

- [ ] 13.1 `bundle exec rspec` — verde, cobertura SimpleCov >= 80%.
- [ ] 13.2 `bundle exec rubocop` — sem offenses; todo `.rb` com `# frozen_string_literal: true`.
- [ ] 13.3 `bundle exec steep check` — sem erros de tipo nas assinaturas `sig/`.
- [ ] 13.4 CI verde nas 3 versões da matriz (Ruby 3.2 / 3.3 / 3.4).
- [ ] 13.5 `openspec validate add-client-core` — passa.
- [ ] 13.6 Confirmar zero dependências de runtime no `*.gemspec` (só stdlib: net/http, json, openssl, uri, securerandom, stringio, time, base64).
