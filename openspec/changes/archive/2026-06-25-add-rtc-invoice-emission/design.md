# Design — add-rtc-invoice-emission

## Context

A **Reforma Tributária do Consumo (RTC)** adiciona os tributos IBS (estadual + municipal), CBS e — só para produto — o Imposto Seletivo (IS) aos documentos fiscais. A `nfeio-docs` publica os leiautes como **duas** OpenAPIs dedicadas:
- `service-invoice-rtc-v1.yaml` (NFS-e; host `https://api.nfe.io`, `version: v3`, snapshot `NT_2025.002_v1.30_RTC`, 18 schemas nomeados; grupo `ibsCbs` no nível raiz).
- `product-invoice-rtc-v1.yaml` (NF-e/NFC-e; host `https://api.nfse.io`, `version: v3`, snapshot `NT_2025.002_v1.30_RTC_NF-e_IBS_CBS_IS`, 140 schemas nomeados, OpenAPI 3.0.1; grupos `IBSCBS` e `IS` no nível do item — `items[].tax`). Única operação na spec: `POST /v2/companies/:companyId/productinvoices` (`createProductInvoice`).

O fato central, ancorado em `docs/documentacao/reforma-tributaria/index.md`, é que **a RTC NÃO cria uma API nova**: ela adiciona grupos de campos e novas versões de layout, e o fluxo de emissão continua o mesmo. A seleção do leiaute RTC é por **forma do payload** (presença de `ibsCbs` na NFS-e; presença do grupo item-level `IBSCBS` na NF-e/NFC-e), sem header nem query param — exatamente os mesmos endpoints que as superfícies clássicas usam.

Esta change reusa as abstrações compartilhadas de `add-client-core` (contrato discriminado 202 `Pending`/`Issued`, `FlowStatus`, `IdValidator`, `download`/`hydrate_list`/`handle_async_response` do `Nfe::Resources::AbstractResource`, `ListResponse`/`ListPage`, host map / roteamento multi-base-URL), os padrões das superfícies clássicas de service-invoice e product-invoice de `add-invoice-resources` (subtipos `Nfe::Resources::ServiceInvoicePending`/`Nfe::Resources::ServiceInvoiceIssued`; ciclo de vida do produto) e a geração de `Data.define` + `.rbs` de `add-openapi-pipeline`, para uma capability fiscal **nova** (NFS-e RTC + NF-e/NFC-e RTC) e ainda em evolução regulatória. Espelha o SDK Node de referência, que modela `serviceInvoicesRtc` E `productInvoicesRtc` na MESMA change RTC.

Diferença de qualidade de tipos vs NFS-e clássica: `nf-servico-v1.yaml` tem **0 component schemas** (o `ServiceInvoice` clássico é derivado de `operations[...]`); ambas as specs RTC definem **schemas nomeados** (`NFSeRequest`/`ibsCbs`; `ProductInvoiceRequest`/`IBSCBSTaxResource`/`ISTaxResource`), então o gerador produz tipos ricos sem ginástica de derivação. Esse é um dos motivos de a RTC ser o "happy path" e poder embarcar de forma independente.

## Goals / Non-Goals

**Goals**
- Emitir NFS-e no leiaute RTC via recurso dedicado `client.service_invoices_rtc`, com o grupo `ibsCbs` no payload.
- Emitir NF-e/NFC-e no leiaute RTC via recurso dedicado `client.product_invoices_rtc`, com os grupos item-level `IBSCBS` (`state`/`municipal`/`cbs`) e `IS` (Imposto Seletivo) no payload.
- Reusar o contrato discriminado 202 de `add-client-core` (`Nfe::Pending`/`Nfe::Issued`) nos dois recursos: `create` retorna `*RtcPending` (202+Location) ou `*RtcIssued` (201+corpo).
- Tipar request/response a partir dos schemas nomeados das specs RTC (`NFSeRequest`/`ibsCbs`; `ProductInvoiceRequest`/`IBSCBSTaxResource`/`ISTaxResource`) gerados por `add-openapi-pipeline` como `Data.define` imutáveis.
- Baixar o XML do evento de cancelamento (`e110001`) da NFS-e via `download_cancellation_xml` (retorna `String` binária `ASCII-8BIT`); baixar PDF/XML/rejeição/EPEC/CC-e da NF-e/NFC-e — todos retornam `Nfe::NfeFileResource` (uma URI), igual à superfície clássica `product_invoices` e ao schema `FileResource{uri}` de `nf-produto-v2.yaml`.
- Oferecer ciclo de vida completo de produto (retrieve/list/cancel/items/events/downloads/CC-e/inutilização) por paridade com a superfície clássica, no mesmo host `api.nfse.io`.
- Validar IDs antes do HTTP (fail-fast) e suportar polling manual via `FlowStatus.terminal?`.
- Deixar os recursos clássicos `service_invoices` e `product_invoices` 100% intactos (RTC é opt-in).

**Non-Goals**
- `create_and_wait` / `create_batch` — diferidos, consistente com `add-invoice-resources`, para ambos os recursos.
- Validação local/runtime dos campos RTC (tabelas de `operationIndicator`/`classCode`/`situationCode`, valores de IS) — a API valida server-side; o SDK só faz fail-fast de ID.
- Cálculo de IBS/CBS/IS — o motor de cálculo (`calculo-impostos-v1`) é outro escopo; aqui o caller informa os valores no payload.
- Novos eventos de pós-autorização do RTC documentados no fluxograma de ciclo de vida — ainda não são endpoints na spec; fora de escopo até virarem paths.

## Decisions

### D1. Recurso dedicado `service_invoices_rtc` (não evoluir o clássico)
**Decisão**: introduzir um recurso novo `client.service_invoices_rtc` em vez de adicionar um modo RTC ao `service_invoices` existente.

**Por quê**:
- Isola o churn regulatório (Notas Técnicas) fora do caminho de emissão clássico — o `service_invoices` não muda de assinatura quando o leiaute RTC evolui.
- Espelha a própria documentação, que entrega RTC como uma spec OpenAPI separada (`service-invoice-rtc-v1.yaml`).
- RTC fica explicitamente opt-in: o caller escolhe `service_invoices_rtc` deliberadamente.
- Espelha a proposta do Node SDK (`serviceInvoicesRtc` / `productInvoicesRtc` dedicados).

**Alternativa rejeitada**: adicionar `ibs_cbs:` opcional ao `service_invoices.create` clássico e detectar RTC por presença do campo. Funciona (é assim que o servidor seleciona), mas acopla o churn RTC à assinatura do recurso clássico e torna o tipo do request ambíguo (clássico-derivado vs `NFSeRequest` nomeado).

### D2. Mesmo endpoint, mesmo host, mesmo host-client `main`
**Decisão**: `service_invoices_rtc` usa `POST /v1/companies/{company_id}/serviceinvoices` no host `https://api.nfe.io` (família `main`; `base_url_for(:main)` retorna o host e o `/v1` vem do `api_version` do recurso, URL efetiva `https://api.nfe.io/v1/...`), reusando o **mesmo** host client do `service_invoices` clássico via `Configuration` — **sem nova base URL**.

**Por quê**: a RTC não introduz endpoint nem host novo (confirmado na spec `servers: https://api.nfe.io` e no recon). O canônico do projeto é "nenhum recurso hard-codeia URL; a fonte única é a `Configuration`". `api_family` do recurso retorna `:main`.

**Implementação**: `ServiceInvoicesRtc#api_family` → `:main`; o Client passa o host client `main` já existente ao instanciar o recurso (lazy), não cria um novo.

### D3. DTO de request a partir do schema nomeado `NFSeRequest`
**Decisão**: o corpo de `create` é tipado pelo `Data.define` gerado `Nfe::Generated::ServiceInvoiceRtcV1::NFSeRequest`, que carrega o grupo aninhado `ibsCbs`. O método também aceita um `Hash` cru (paridade com os demais recursos), serializado com as chaves JSON originais.

**Por quê**:
- Os schemas nomeados da spec RTC geram tipos ricos (★★★), superiores ao caminho derivado de `operations[...]` da NFS-e clássica.
- `Data.define` é imutável e idiomático em Ruby moderno; valores são value objects sem efeito colateral.
- Aceitar `Hash` mantém ergonomia para quem monta o payload à mão a partir dos exemplos da spec (`MinimumExample`, `IntermediateExample`, `CompleteExample`).

**Mapeamento `ibsCbs`** (campos-chave, em `snake_case` no Ruby, chave JSON original preservada):

| Ruby | JSON | Notas |
|---|---|---|
| `operation_indicator` | `operationIndicator` / `cIndOp` | obrigatório, `^[0-9]{6}$`, define local de incidência IBS/CBS |
| `class_code` | `classCode` / `cClassTrib` | obrigatório, max 6 |
| `situation_code` | `situationCode` / CST | opcional, max 3 — derivável dos 3 primeiros chars de `class_code` |
| `purpose` | `purpose` | enum `regular` (default) |
| `destination_indicator` | `destinationIndicator` | `SameAsBuyer` (default) / `DifferentFromBuyer` |
| `ibs.state` / `ibs.municipal` | `ibs.state`/`ibs.municipal` | cada um com `rate`/`effective_rate`/`deferment`/`amount` |
| `cbs` | `cbs` | `rate`/`effective_rate`/`deferment`/`amount` |
| `regular_taxation`, `presumed_credits`, `government_purchase`, `credit_transfer`, `third_party_reimbursements` | idem | mecanismos RTC especiais |

`required: [class_code, operation_indicator]` no grupo `ibsCbs` (confirmado na spec). O SDK NÃO valida esses campos localmente além do que o gerador emite — quem valida o conteúdo é a API.

### D4. Contrato discriminado 202 reusado, com classes RTC concretas
**Decisão**: criar `Nfe::Resources::ServiceInvoiceRtcPending` e `Nfe::Resources::ServiceInvoiceRtcIssued`, implementando os protocolos `Nfe::Pending`/`Nfe::Issued` definidos em `add-client-core` (espelhando os subtipos concretos `Nfe::Resources::ServiceInvoicePending`/`Nfe::Resources::ServiceInvoiceIssued` de `add-invoice-resources`). Cada classe expõe também os predicados `pending?`/`issued?`, de modo que a discriminação funcione tanto por `is_a?` quanto por predicado — igual aos subtipos clássicos.

```ruby
Nfe::Resources::ServiceInvoiceRtcPending  # implementa Pending: invoice_id, location, pending? => true, issued? => false
Nfe::Resources::ServiceInvoiceRtcIssued   # implementa Issued: resource -> DTO RTC, issued? => true, pending? => false
```

**Por quê**:
- Mantém `is_a?(Nfe::Resources::ServiceInvoiceRtcPending)` (e `result.pending?`) semanticamente preciso e distinto do `Nfe::Resources::ServiceInvoicePending` clássico.
- Reusa a extração de `invoice_id` do header `Location` (regex `%r{serviceinvoices/([a-z0-9-]+)}i`) já definida em `add-invoice-resources` — não duplicar.
- 202 sem `Location` → `Nfe::InvoiceProcessingError` (mesmo contrato do clássico).

**Alternativa rejeitada**: reusar as classes `Nfe::Resources::ServiceInvoicePending`/`Nfe::Resources::ServiceInvoiceIssued` do clássico. Funcionaria, mas perde a distinção de tipo e acopla o `resource()` ao DTO clássico (derivado), não ao DTO RTC nomeado.

### D5. `create_and_wait` / `create_batch` diferidos
**Decisão**: NÃO implementar nesta change. Caller usa loop manual com `Nfe::FlowStatus.terminal?` (helper público de `add-client-core`):

```ruby
result = client.service_invoices_rtc.create(company_id: cid, data: payload)
if result.is_a?(Nfe::Resources::ServiceInvoiceRtcPending)
  loop do
    sleep 2
    invoice = client.service_invoices_rtc.retrieve(company_id: cid, invoice_id: result.invoice_id)
    break if Nfe::FlowStatus.terminal?(invoice.flow_status)
  end
end
```

**Por quê**: consistência com a decisão já cristalizada em `add-invoice-resources` (Node difere ambos para release futura; PHP v3.0 os defere). Estados terminais: `Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`.

### D6. `download_cancellation_xml` retorna `String` binária
**Decisão**: `download_cancellation_xml(company_id:, invoice_id:)` faz `GET .../cancellation-xml` com `Accept: application/xml` e retorna `String` binária (`force_encoding('ASCII-8BIT')`), via o helper `download` do `Nfe::Resources::AbstractResource`.

**Por quê**:
- Canônico do projeto: downloads retornam bytes crus binary-safe (não `Buffer`/`StringIO`); o caller decide se grava em disco.
- O endpoint é **novo do RTC** (Release 2026.5, 2026-06-04): baixa o XML do evento de cancelamento (`e110001`) **separado** do XML de emissão. Disponível **apenas** no Ambiente Nacional (ADN) e só após status `Cancelled`. Quando há tanto o request `e110001` quanto o retorno autorizado (`procEventoNFSe`), a API prioriza o autorizado.

**Tratamento de erro**: provedores municipais/ABRASF não têm evento de cancelamento próprio → a API retorna `404`. O SDK mapeia para `Nfe::NotFoundError` (mesmo mapeamento HTTP→erro definido em `add-client-core`); documentamos que esse 404 é esperado fora do Ambiente Nacional.

### D7. Validação fail-fast de IDs antes do HTTP
**Decisão**: cada método chama `Nfe::IdValidator.company_id` / `Nfe::IdValidator.invoice_id` (de `add-client-core`) no início, levantando `Nfe::InvalidRequestError` em pt-BR antes de qualquer chamada de rede.

**Por quê**: paridade com os demais recursos; mensagem clara e cedo. O `service-invoice-rtc-v1.yaml` declara `company_id` e `id` como `string` obrigatórios — apenas garantimos não-vazio (a API valida o resto).

### D8. Snapshot da spec fixado e re-sync por Nota Técnica
**Decisão**: o leiaute RTC é tratado como **snapshot fixado** (`NT_2025.002_v1.30_RTC`, `version: v3`). O gerador sincroniza a partir de `nfeio-docs`; a cada Nota Técnica relevante, re-sincroniza-se a spec e re-geram-se os DTOs.

**Por quê**: o próprio cabeçalho da spec avisa "Sujeito a alterações mediante notas técnicas e processos de homologação". Fixar o snapshot evita surpresas e torna explícito quando o SDK precisa de atualização. Registrado também como Risco abaixo.

### D9. Accessor lazy e contagem de recursos
**Decisão**: `client.service_invoices_rtc` é um accessor lazy memoizado, igual aos demais. Eleva a contagem de accessors de 17 para 18, documentado como **adendo RTC / paridade-plus** (não faz parte dos 17 recursos canônicos do PHP/Node).

**Por quê**: mantém o estilo Stripe-like (single client + accessors lazy) e deixa explícito, para mantenedores futuros, que `service_invoices_rtc`/`product_invoices_rtc` são acréscimos deliberados do leiaute RTC e não fazem parte dos 17 recursos de paridade. A contagem de accessors passa de 17 para 19.

### D10. Recurso dedicado `product_invoices_rtc` no host `cte`/`api.nfse.io`
**Decisão**: introduzir `client.product_invoices_rtc` para emitir NF-e (modelo 55) e NFC-e (modelo 65) no leiaute RTC. `api_family` → `:cte` (alias `:product_invoices`), `api_version` → `"v2"`, resolvendo `https://api.nfse.io/v2/...` via `Configuration#base_url_for(:cte)` — **o MESMO host e base do `product_invoices` clássico**, sem nova base URL.

**Por quê**:
- A spec RTC de produto declara `servers: https://api.nfse.io` (descrição "Nota Fiscal de Produto/Consumidor (RTC)"). Esse é o host da família `cte` (onde já vivem `product_invoices`, `consumer_invoices`, `transportation_invoices`, etc., confirmado no host map de `add-client-core`). O Node roteia o RTC de produto via `getCteHttpClient()` (o cliente `api.nfse.io`).
- **NÃO** rotear o produto RTC para `api.nfe.io` (esse é o host `main`, da NFS-e). Discrepância de fonte sinalizada no recon: a prosa do design Node menciona `getCteHttpClient`, que É o cliente `api.nfse.io` no Node — em Ruby mapeamos para a família `:cte`.
- Isola o churn regulatório fora do `product_invoices` clássico; RTC opt-in; espelha o `productInvoicesRtc` do Node.

### D11. NF-e (mod 55) vs NFC-e (mod 65): UM recurso, UM endpoint, distinção por forma do payload
**Decisão**: um único `product_invoices_rtc` cobre NF-e E NFC-e. Não há campo discriminador `model`/`mod` na raiz do `ProductInvoiceRequest` nem endpoints separados. A distinção é por **forma do payload**:

| Aspecto | NF-e (modelo 55) | NFC-e (modelo 65) |
|---|---|---|
| `print_type` (`PrintType`) | `NFeNormalPortrait`/`NFeNormalLandscape`/`NFeSimplified` | `DANFE_NFC_E`/`DANFE_NFC_E_MSG_ELETRONICA` |
| `consumer_type` (indFinal) / `presence_type` (indPres) | conforme operação | tipicamente `FinalConsumer` + `Internet`/`Presential` |
| `buyer` (dest) | **obrigatório** | opcional |
| `expected_delivery_on` | pode ser informado | NÃO informar |

**Por quê**: a spec é "Leiaute NFe/NFCe RTC — Modelo 55 e 65" com uma só operação `createProductInvoice`. O campo `mod` só aparece em sub-schemas de documento referenciado (`TaxCouponInformationResource.modelDocumentFiscal`, `DocumentInvoiceReferenceResource`), não na raiz do request. Logo o SDK não precisa de um seletor: o caller popula os campos opcionais conforme o modelo. Não enviamos nenhum header/param discriminador.

### D12. Grupos de tributo RTC no nível do ITEM; IBS dividido estadual+municipal; CBS federal; IS exclusivo de produto
**Decisão**: tipar os grupos RTC de produto onde a spec os coloca — em `InvoiceItemTaxResource` (`items[].tax`), lado a lado com os grupos legados (`icms`/`ipi`/`ii`/`pis`/`cofins`/`icmsDestination`). DOIS grupos novos:
- `IBSCBS` → `IBSCBSTaxResource`, que nesta (vs NFS-e) carrega `state` → `IBSStateTaxResource` e `municipal` → `IBSMunicipalTaxResource` (IBS é de competência compartilhada → split estadual/municipal), e `cbs` → `CBSTaxResource` (federal, SEM split). Cada esfera de IBS carrega `rate`/`deferment`/`returned_amount`/`reduction`/`amount`. Inclui `calculation_mode` (`Manual`|`OfficialService`) e mecanismos especiais (`regular_taxation`, `government_purchase`, `monophase`, `credit_transfer`, `operational_presumed_credit`, `credit_reversal`, `zfm_presumed_credit`).
- `IS` → `ISTaxResource` (Imposto Seletivo), tributo **novo e EXCLUSIVO de produto**: `situation_code`, `classification_code`, `basis`, `rate`, `unit_rate`, `unit`, `quantity`, `amount`.

**Contraste com NFS-e RTC**: a NFS-e RTC tem só um grupo `ibsCbs` no nível RAIZ (com `operation_indicator` + `class_code`, sem split estadual/municipal e SEM Imposto Seletivo). O split estadual/municipal do IBS, os mecanismos por esfera (deferment/returnedAmount/reduction) e o IS são **exclusivos do produto**.

**Por quê**: refletir fielmente a spec (140 schemas) — não inventar estrutura. Mantém `Hash` como fallback no caminho de request caso o gerador seja raso em algum subgrupo aninhado.

### D13. Contrato 202 discriminado para produto, apesar de a spec documentar 201
**Decisão**: criar `Nfe::Resources::ProductInvoiceRtcPending`/`Nfe::Resources::ProductInvoiceRtcIssued` (implementando `Pending`/`Issued`) e tratar a resposta de `create` de forma discriminada: 202+`Location` → Pending; 201+corpo → Issued. Extração de `invoice_id` via `%r{productinvoices/([a-z0-9-]+)}i`; 202 sem `Location` → `Nfe::InvoiceProcessingError`.

**Por quê**: a spec RTC documenta o POST como `201` (→ `InvoiceResource`), mas a superfície clássica de produto trata o MESMO POST como `202`-enfileirado. A emissão é **sempre assíncrona** (conclusão por webhook/polling), independentemente do código. Tratar ambos via o mesmo contrato discriminado de `add-client-core` cobre as duas formas sem acoplar o caller ao código HTTP. `cancel`/CC-e/inutilização também são assíncronos (cancel = 204-enfileirado → `RequestCancellationResource`).

### D14. Ciclo de vida completo carregado da superfície clássica de produto
**Decisão**: além do `create` (única operação que a spec RTC define), `product_invoices_rtc` expõe `create_with_state_tax`, `retrieve`, `list`, `cancel`, `list_items`, `list_events`, downloads (`pdf`/`xml`/`xml-rejection`/`xml-epec`), CC-e (`send_correction_letter` + downloads) e inutilização (`disable`/`disable_range`) — todos carregados da superfície **clássica** `product_invoices`.

**Por quê**: os métodos clássicos compartilham host (`api.nfse.io`), base (`/v2`) e tipos de resposta (`InvoiceResource` é o mesmo que o `create` RTC retorna), então dão ao recurso RTC um ciclo de vida completo sem nova infra — exatamente como o Node prevê layering por cima do `productInvoicesRtc.create`. **Ambiente Nacional NÃO se aplica ao produto** (NF-e/NFC-e vai direto à SEFAZ), portanto produto não tem `download_cancellation_xml`; em vez disso usa `xml-rejection`/`xml-epec` e o ciclo de CC-e/inutilização.

## Risks / Trade-offs

| Risco | Mitigação |
|---|---|
| Leiaute RTC sujeito a Notas Técnicas / homologação; campos podem mudar | Tratar a spec como snapshot fixado (`NT_2025.002_v1.30_RTC`); re-sync + re-gen a cada NT; comunicar em doc que é "evolving" |
| Dois caminhos de emissão de NFS-e (clássico vs RTC) confundem o usuário | Nomes distintos (`service_invoices` vs `service_invoices_rtc`); RTC explicitamente opt-in; README com exemplo claro de quando usar cada um |
| `download_cancellation_xml` (NFS-e) só existe em Ambiente Nacional → 404 em municipal/ABRASF | Documentar o 404 esperado; mapear para `Nfe::NotFoundError`; deixar claro o pré-requisito de status `Cancelled` |
| Roteamento do produto RTC para o host errado (`api.nfe.io` em vez de `api.nfse.io`) | `api_family` → `:cte` (mesmo host do `product_invoices` clássico); teste de roteamento assertando `https://api.nfse.io`; discrepância de fonte (prosa do Node) explicitada em D10 |
| Spec RTC de produto documenta `create` como `201`, mas o fluxo é assíncrono (clássico = `202`) | Contrato discriminado trata 201 E 202; emissão sempre tratada como assíncrona (Pending/Issued); doc deixa explícito |
| 140 schemas de produto: gerador pode não tipar todos os subgrupos aninhados de `IBSCBS`/`IS` | Validar na §7 das tasks; `Hash` como fallback no caminho de request mantém ergonomia |
| Confundir grupo raiz `ibsCbs` (NFS-e) com grupo item-level `IBSCBS` (produto), ou esperar IS/split estadual-municipal na NFS-e | D12 documenta o contraste; recursos e DTOs separados (`service_invoice_rtc_v1` vs `product_invoice_rtc_v1`) |
| Geração de DTO pode não cobrir todos os subgrupos aninhados de `ibsCbs` se o gerador for raso em `additionalProperties: false` | Validar na §1 das tasks que o subgrupo `ibsCbs` e seus filhos (`ibs.state`/`ibs.municipal`/`cbs`/mecanismos) geram tipos; fallback para `Hash` no caminho de request mantém ergonomia mesmo se algum subgrupo não tipar |
| `operationIndicator` errado leva a apuração de imposto incorreta | Fora do controle do SDK (validação de conteúdo é server-side); documentar link para a Tabela de `operationIndicator` da doc funcional |
| Acoplamento à ordem de entrega das dependências (`add-client-core`, `add-invoice-resources`, `add-openapi-pipeline`) | Cross-reference explícito; esta change não inicia até os protocolos `Pending`/`Issued`, `FlowStatus`, `IdValidator`, `download` (de `add-client-core`) e o pipeline estarem disponíveis |
