# Design — add-invoice-resources

## Context

`add-client-core` montou o terreno: `Nfe::Client` com acessores lazy snake_case, transporte `Net::HTTP` (stdlib, zero dependências de runtime), `Nfe::Configuration` com o host map por família, hierarquia de erros tipados, e o contrato de resposta discriminada 202 (`Pending`/`Issued`). Esta change é o **primeiro consumidor real** desses blocos — os cinco recursos de invoice, que têm três perfis distintos:

- **Emissão (síncrona/assíncrona)** — `service_invoices`, `product_invoices`, `consumer_invoices`: consomem o contrato 202, têm downloads, cancelamento, eventos, cartas de correção e inutilização.
- **Inbound settings + consulta** — `transportation_invoices` (CT-e), `inbound_product_invoices` (NF-e de fornecedores): não emitem — gerenciam auto-fetch via Distribuição DFe e consultam por `access_key` de 44 dígitos.

Recon (Node SDK + PHP SDK + nfeio-docs) revelou três fatos que moldam o design:

- O SDK Node expõe **16 recursos**; o PHP adiciona um 17º, `consumer_invoices` (emissão NFC-e), porque a API NFE.io oferece esse lifecycle completo em `nf-consumidor-v2.yaml`. Replicamos a decisão PHP: `consumer_invoices` entra como **paridade-plus**.
- `product_invoices.download_*` retorna uma **URI** (`NfeFileResource`), não bytes — divergência de contrato vs os demais downloads (que retornam bytes).
- A emissão RTC (IBS/CBS/IS) é um modelo NOVO de payload e fica na change separada `add-rtc-invoice-emission`; aqui implementamos só a emissão clássica.

## Goals / Non-Goals

**Goals**
- 5 recursos: 4 com paridade 1:1 de método-por-método com o Node SDK + 1 paridade-plus (NFC-e).
- Retorno discriminado `<Type>Pending | <Type>Issued` concreto para `create()` quando há contrato 202 (service, product, consumer).
- Downloads de bytes retornam `String` em `ASCII-8BIT` (binary-safe); downloads de `product_invoices` retornam `NfeFileResource` (URI), conforme a API.
- Validação de IDs e `access_key` antes do HTTP (fail-fast, mensagem clara em pt-BR).
- `ListResponse`/`ListPage` genéricos que cobrem os dois shapes de paginação (page-style e cursor-style).
- `FlowStatus.terminal?` para habilitar polling manual.
- Cobertura RSpec com WebMock para happy path + 202 + 201 + 400/404 + cancel + paginação + routing por host.

**Non-Goals**
- `create_and_wait` / helper de polling — confirmado fora de escopo em `add-client-core`; caller escreve loop manual com `FlowStatus.terminal?`.
- `create_batch` — açúcar concorrente sem ganho no modelo síncrono do SDK Ruby.
- Streaming de downloads — retornamos a `String` completa; arquivos muito grandes ficam para release futura.
- Validação de dígito verificador de CNPJ/CPF na emissão — a API valida no servidor; replicar local seria custoso e duplicado (fica para os recursos de entidade, fora desta change).
- Emissão RTC (IBS/CBS/IS) — coberta por `add-rtc-invoice-emission`.

## Decisions

### D1. Pares de value objects concretos por família de invoice
**Decisão**: criar pares `Data.define` em `Nfe::Resources::`:

```
ServiceInvoicePending(:invoice_id, :location)   # pending? => true
ServiceInvoiceIssued(:resource)                 # issued?  => true
ProductInvoicePending / ProductInvoiceIssued
ConsumerInvoicePending / ConsumerInvoiceIssued
```

**Por quê**:
- Mantém `result.is_a?(ServiceInvoicePending)` e `case result; in ServiceInvoicePending` (pattern matching de `Data`) semanticamente precisos por família.
- `Data.define` dá value objects imutáveis e comparáveis por valor de graça (alinhado com a decisão canônica de modelos imutáveis).
- Se a API um dia adicionar um terceiro estado, adiciona-se um novo `Data` sem mexer nos existentes.

**Alternativa rejeitada**: um único par genérico `InvoicePending`/`InvoiceIssued`. Funciona, mas o pattern matching fica ambíguo entre tipos de invoice e a inferência RBS fica frouxa.

### D2. Discriminação por status HTTP + header `Location`
**Decisão**: `create()` decide o tipo de retorno pelo status: 202 → `*Pending` (extrai `invoice_id` do header `Location` via regex), 201 → `*Issued` (hidrata o body). Se 202 vier sem `Location` ou o ID não for extraível, levantar `Nfe::InvoiceProcessingError`.

Regex de extração (paridade Node): service usa `%r{serviceinvoices/([a-z0-9-]+)}i`; product/consumer usam o segmento correspondente. Se o `Location` for URL absoluta, extrair o `path` antes (via `URI`).

**Por quê**: é o contrato cravado em `add-client-core` e no SDK Node. O header `Location` é a única fonte do `invoice_id` no caso async.

### D3. Cada recurso desempacota seu próprio envelope
**Decisão**: o desempacotamento do envelope (`{ "serviceInvoice" => {...} }`, `{ "serviceInvoices" => [...] }`) acontece no recurso, via helper `Base#unwrap(payload, *keys)` que retorna a primeira chave presente ou o `payload` cru. A `Base` não conhece os wrappers específicos.

**Por quê**: cada endpoint conhece seu envelope; centralizar na base viraria uma cascata de condicionais. O helper só fornece o mecanismo, não o conhecimento.

### D4. Downloads de bytes retornam `String` em ASCII-8BIT
**Decisão**: `download_pdf`, `download_xml`, `download_rejection_xml`, `download_event_xml`, `get_xml`, `get_event_xml`, `get_pdf` (service/consumer/transportation/inbound) retornam `String` com `force_encoding(Encoding::ASCII_8BIT)`. Helper `Base#download(path, accept:)` faz GET, valida 200 e devolve `response.body` cru, sem tentar `JSON.parse`.

**Por quê**:
- Ruby `String` é binary-safe; `ASCII-8BIT` evita corrupção de bytes de PDF/ZIP por re-encoding UTF-8.
- O caller decide se persiste (`File.binwrite("x.pdf", bytes)`) ou faz stream para uma resposta HTTP.
- Adapta o `Buffer` do Node (a decisão canônica manda `Buffer → String` binária).

### D5. `product_invoices.download_*` retorna `NfeFileResource` (URI), não bytes
**Decisão**: ao contrário de D4, os downloads de `product_invoices` (pdf/xml/rejection/epec/correction-letter) retornam um `Nfe::Models::NfeFileResource` que carrega a URI do arquivo. Isso é comportamento da API NF-e (a API devolve um recurso com link, não os bytes).

**Por quê**: paridade com o Node (`NfeFileResource`) e com a API real. Documentar explicitamente para o caller não confundir com os downloads dos outros recursos. O caller faz o GET na URI por conta própria (ou via um helper futuro).

**Alternativa rejeitada**: normalizar tudo para bytes baixando a URI internamente. Rejeitada — esconderia a semântica real da API e adicionaria um round-trip implícito não solicitado.

### D6. Validators fail-fast consumindo `Nfe::IdValidator` (de add-client-core)
**Decisão**: consumir o módulo `Nfe::IdValidator` já definido em `add-client-core` (NÃO redefinir, NÃO criar `Nfe::Util::IdValidator`):

```ruby
Nfe::IdValidator.company_id(value)    # raise InvalidRequestError se vazio/branco
Nfe::IdValidator.invoice_id(value)
Nfe::IdValidator.state_tax_id(value)
Nfe::IdValidator.event_key(value)
Nfe::IdValidator.access_key(value)    # normaliza p/ dígitos, valida /\A\d{44}\z/, retorna a String
```

`access_key` aceita formato com espaços/pontos/traços, remove não-dígitos e valida 44 dígitos (paridade com o `/^\d{44}$/` do Node). Cada método levanta `Nfe::InvalidRequestError` (de `add-client-core`) com mensagem em pt-BR identificando o argumento.

**Por quê**: fail-fast antes do HTTP, paridade com `validateCompanyId`/`validateAccessKey` do Node, e mensagens na língua da audiência. Reutilizar o validador canônico de `add-client-core` evita duplicar a abstração em namespace incompatível.

### D7. `consumer_invoices` é paridade-plus (NFC-e), com 3 ausências por lei fiscal
**Decisão**: `consumer_invoices` é implementado e exposto em `client.consumer_invoices`, mesmo o Node não o tendo. Fundamentação: `nf-consumidor-v2.yaml` cobre o lifecycle completo de NFC-e. Documentar como paridade-plus no cabeçalho da classe.

O recurso **NÃO** replica 3 métodos do `product_invoices`:

| Método ausente em NFC-e | Justificativa fiscal |
|---|---|
| `send_correction_letter` (CC-e) | Carta de correção é instrumento fiscal só do NF-e. |
| `download_epec_xml` | EPEC (Evento Prévio de Emissão em Contingência) só existe para NF-e. |
| `disable` por invoice | NFC-e suporta apenas inutilização coletiva via `disable_range`. |

Essas ausências são propriedades da legislação fiscal brasileira, não limitações do SDK. Testar que esses métodos levantam `NoMethodError`.

**Por quê**: paridade com o Node é o **piso**, não o teto. Quando a API oferece um recurso real e há demanda concreta (PoS, e-commerce que emite NFC-e), expor faz sentido. Paridade-plus documentada evita que mantenedores futuros confundam com phantom. Espelha a decisão D7 do PHP SDK.

### D8. `ListResponse`/`ListPage` (de add-client-core) cobrem os dois shapes de paginação
**Decisão**: consumir os tipos já definidos em `add-client-core` (NÃO redefinir sob `Nfe::Util::`):

```ruby
Nfe::ListPage = Data.define(:page_index, :page_count, :starting_after, :ending_before, :total)
Nfe::ListResponse = Data.define(:data, :page)   # inclui Enumerable, each => data.each
```

O recurso preenche a metade relevante: service usa page-style (`page_index`/`page_count`); product/consumer usam cursor-style (`starting_after`/`ending_before`). O caller usa `result.data` igual nos dois casos e pode iterar direto (`result.each`).

**Por quê**: um tipo só, amigável ao caller, reutilizado de `add-client-core`. `ListResponse` incluir `Enumerable` é idioma Ruby (vs forçar `result.data.each`).

**Alternativa rejeitada**: dois tipos (`PageListResponse` + `CursorListResponse`). Mais "correto" mas força o caller a discriminar.

### D9. `FlowStatus.terminal?` + polling manual; `create_and_wait`/`create_batch` diferidos
**Decisão**: NÃO implementar `create_and_wait` nem `create_batch`. Consumir `Nfe::FlowStatus.terminal?(status)` (de `add-client-core`; true para `Issued`, `Cancelled`, `IssueFailed`, `CancelFailed`) e documentar o loop manual no README:

```ruby
result = client.service_invoices.create(company_id:, data:)
if result.pending?
  loop do
    sleep 2
    invoice = client.service_invoices.retrieve(company_id:, invoice_id: result.invoice_id)
    break if Nfe::FlowStatus.terminal?(invoice.flow_status)
  end
end
```

**Por quê**: consistência com `add-client-core`. Quando um helper de polling chegar (release futura), `terminal?` já está pronto. O PHP SDK também diferiu ambos.

### D10. `get_status` é derivado de `retrieve` (sem HTTP extra)
**Decisão**: `service_invoices.get_status` NÃO faz chamada HTTP própria — chama `retrieve` e computa o resultado (`status`, `invoice`, `complete?`, `failed?`) a partir do `flow_status`, via `FlowStatus.terminal?` e checagem de `IssueFailed`/`CancelFailed`.

**Por quê**: paridade com o Node (que deriva de `retrieve()`). NOTA de divergência: a tabela do spec PHP promete um endpoint real `GET /status`; seguimos o Node (derivado) por ser o comportamento de produção observado.

### D11. Manifestação inbound usa códigos numéricos `tpEvent`
**Decisão**: `inbound_product_invoices.manifest(tp_event: 210210)` aceita códigos numéricos: `210210` Ciência (default), `210220` Confirmação, `210240` Operação não Realizada. Expor constantes simbólicas no módulo (`MANIFEST_AWARENESS`, `MANIFEST_CONFIRMATION`, `MANIFEST_NOT_PERFORMED`).

**Por quê**: paridade com o Node (`ManifestEventType` numérico). NOTA de divergência: o spec PHP usa labels string (Confirmation/Acknowledgement/Unknown/Refused); seguimos o Node numérico, que casa com o `tpEvent` real da SEFAZ.

### D12. Onde colocam-se modelos hand-written quando o gerador for incompleto
**Decisão**: `lib/nfe/models/<...>.rb` (ex.: `lib/nfe/models/nfe_file_resource.rb`, `lib/nfe/models/service_invoice.rb`), separados de `lib/nfe/generated/`.

**Por quê**:
- NÃO vai em `lib/nfe/generated/` (o guard de sync do gerador reclamaria; a decisão canônica proíbe hand-edit de gerados).
- `nf-servico-v1.yaml` tem 0 schemas de componente — o modelo de service-invoice é necessariamente derivado/hand-written.
- Fica visível como complemento hand-written, com RBS próprio em `sig/nfe/models/`.

### D13. Idempotência e opções por chamada nos métodos de emissão (decisão de mantenedor)
**Decisão**: os métodos de emissão — `create` e `create_with_state_tax` de `service_invoices`, `product_invoices` e `consumer_invoices` — aceitam dois kwargs opcionais:

```ruby
client.service_invoices.create(company_id:, data:, idempotency_key: nil, request_options: nil)
```

- `idempotency_key:` — quando fornecido, é enviado como header HTTP `Idempotency-Key`. O caller supre uma chave **estável** atrelada ao id de negócio (ex.: número do pedido). Documenta-se o padrão de retry seguro: após um timeout, o caller **repete a chamada com a MESMA chave**, evitando emitir um documento fiscal duplicado. O POST continua **não** sendo auto-retentado pelo transporte (a default de segurança de `add-http-transport` permanece).
- `request_options:` — aceita um `Nfe::RequestOptions` (de `add-client-core`, `Data.define(:api_key, :base_url, :timeout)`); a `AbstractResource` encaminha ao request e o transporte honra os overrides por chamada (habilita api_key multi-tenant por chamada sem instanciar um segundo `Client`).

**Por quê**: emissão fiscal é a operação mais perigosa de duplicar — um documento emitido duas vezes vira passivo tributário. A chave de idempotência fornecida pelo caller é a única forma segura de tornar o retry de POST idempotente sem auto-retry cego. As opções por chamada destravam multi-tenancy sem o custo de um `Client` por tenant.

## Risks / Trade-offs

| Risco | Mitigação |
|---|---|
| Envelopes de resposta variam por endpoint sem padrão único (`{serviceInvoice:...}` vs `{serviceInvoices:[...]}` vs plano) | `Base#unwrap` por recurso; documentar o wrapper descoberto no comentário de cada método. |
| Modelos gerados podem não cobrir o shape de resposta (gerador cobre só `components.schemas`; `nf-servico-v1.yaml` tem 0) | Fallback para `Data.define` hand-written em `lib/nfe/models/`; documentar quais foram criados (tasks §9.2). |
| Regex de `access_key` (44 dígitos) é frouxa e aceita sequências inválidas | Aceitável — validação local é fail-fast para typo, não substitui validação server-side. |
| Paginação cursor-style (product/consumer) vs page-style (service) confunde o caller | Documentar em cada `list` qual shape de `ListPage` é preenchido; `ListResponse` aceita ambos e expõe `data` uniformemente. |
| `consumer_invoices` é paridade-plus sem referência cruzada no Node | Smoke test em sandbox antes do GA (tasks §13.5); fundamentação em `nf-consumidor-v2.yaml`. |
| `product_invoices.download_*` retorna URI, não bytes — viola a expectativa "downloads = bytes" | Modelo dedicado `NfeFileResource` + nota explícita no spec e no README; testar que o retorno é URI, não String binária. |
| Cancelamento pode ser async (202) em algum endpoint | service/consumer: tratado como síncrono (retorna modelo atualizado), conforme observado no Node; se a API mudar para 202, expandir via release menor aditiva. |

## Resolved (durante recon — 2026-06-24)

### R1. Modelo principal de service-invoice é hand-written
**Achado**: `nf-servico-v1.yaml` tem **0 schemas de componente** — o `ServiceInvoiceData` do Node é tratado como objeto aberto (`Record<string, any>`). Não há DTO de resposta gerável.
**Decisão**: criar `lib/nfe/models/service_invoice.rb` (`Data.define`) com os campos que o SDK realmente acessa em produção (`id`, `flow_status`, `flow_message`, `status`, `environment`, `rps_number`, `rps_serial_number`, …). Tarefa em §9.2.

### R2. Cancelamento de service é síncrono
**Achado**: `service-invoices.ts` faz `await this.http.delete(...)` e retorna `response.data` sem tratamento de 202 — confirmado HTTP 200 + modelo.
**Decisão**: `cancel` retorna o modelo de invoice atualizado (síncrono). Para `product_invoices`, `cancel` é async (204 enfileirado → recurso de cancelamento).

### R3. Estados terminais cravados
**Achado**: `client-nodejs/src/core/types.ts` define exatamente `Issued`, `IssueFailed`, `Cancelled`, `CancelFailed` como terminais; não-terminais: `PullFromCityHall`, `WaitingCalculateTaxes`, `WaitingDefineRpsNumber`, `WaitingSend`, `WaitingSendCancel`, `WaitingReturn`, `WaitingDownload`.
**Decisão**: `FlowStatus::TERMINAL` e `NON_TERMINAL` espelham essas listas; `terminal?` retorna true para exatamente os 4 valores.

### R4. `product_invoices.list` exige `environment`
**Achado**: a `list` de product usa cursor (`starting_after`/`ending_before`/`limit`/`q`) e exige `environment` (`Production`/`Test`) — o Node levanta erro de validação se ausente.
**Decisão**: `environment:` é keyword obrigatória em `product_invoices.list`; ausência → `InvalidRequestError` antes do HTTP.

### R5. Carta de correção valida tamanho client-side
**Achado**: `sendCorrectionLetter` valida `15 <= len <= 1000` (sem acentos) antes do HTTP.
**Decisão**: `send_correction_letter` valida o tamanho do `reason` client-side e levanta `InvalidRequestError` fora do range, antes do HTTP. Apenas em `product_invoices` (não existe em `consumer_invoices`).

### R6. RTC fora de escopo
**Achado**: as specs RTC (`service-invoice-rtc-v1.yaml`, `product-invoice-rtc-v1.yaml`) são source-of-truth mas representam um modelo NOVO de emissão (grupos IBS/CBS/IS), com seleção por shape de payload.
**Decisão**: a emissão RTC fica em `add-rtc-invoice-emission`. Esta change implementa a emissão clássica e cruza-referência com aquela change; os padrões de 202/polling/host routing definidos aqui são reutilizados lá.
