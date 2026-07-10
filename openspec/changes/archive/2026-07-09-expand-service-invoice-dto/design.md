# Design: expand-service-invoice-dto (client-ruby)

## Context

`Nfe::ServiceInvoice` (`lib/nfe/resources/dto/service_invoice.rb`) é `Data.define` manuscrito com 21 membros (19 reais + 2 fantasmas `pdf`/`xml`), enquanto o retrieve real devolve **44 campos** (schema inline no path `/v1/companies/{company_id}/serviceinvoices/{id}` de `openapi/nf-servico-v1.yaml`). O gerador lê apenas `components.schemas` (`scripts/generator/spec_loader.rb`), e a resposta de sucesso é inline — por isso não existe modelo gerado de `ServiceInvoice`. Estado do spec (2026-07-09): a versão do working tree (não commitada) adiciona `components.schemas.ErrorsResource`; com ela o spec deixa de ser pulado e `rake generate` passa a emitir `lib/nfe/generated/nf_servico_v1/` **apenas com o modelo de erros** — o commit desse yaml precisa levar junto a saída de `rake generate` (senão `rake generate:check` quebra a CI; verificado em Docker) e atualizar as referências obsoletas (`openapi/README.md` cita o spec como pulado; o docblock do DTO diz "defines NO component schemas"). O `from_api` descarta chaves desconhecidas — sem `:raw`, ~25 campos são perdidos.

Referência 1:1: change `expand-service-invoice-dto` do client-php (D1–D6 fechados lá). Diferenças do lado Ruby:
- O Ruby **já tem** os campos de alto valor que o PHP adicionou (`number`, `check_code`, `description`, `city_service_code`, `amount_net`) — o escopo tipado aqui são só os 3 de ISS.
- O `from_api` é o **único ponto de hidratação** (list via `hydrate_list`, retrieve/cancel via `hydrate`, 201-issued via `handle_async_response`) — popular `raw` é um edit em um lugar, não em 5 call-sites como no PHP.
- **`borrower` já é comportamento vivo** como Hash cru (no PHP o campo não era exposto) — tipar exige ponte de compatibilidade (D3).

## Goals / Non-Goals

**Goals:**
- Nenhum campo do retrieve inacessível: 44/44 via `raw`, os de maior valor tipados.
- `borrower` tipado sem quebrar leituras Hash existentes.
- Teste de alinhamento YAML↔DTO que impede drift e sinaliza a hora de migrar ao gerado.

**Non-Goals:**
- Tipar os 44 campos (gradiente de valor; `provider` com 21 subcampos fica em `raw`).
- Componentizar a resposta no `nfe/docs` (upstream, issue à parte) ou alterar o gerador.
- Remover `pdf`/`xml` (deprecação apenas; remoção na próxima major).

## Decisions

### D1 — `:raw` populado no `from_api` (fundação)
Membro `:raw` recebendo o `payload` completo, copiando `Nfe::ConsumerInvoice` ("preserved under raw for forward compatibility", `raw: payload`). Como todos os call-sites hidratam por `from_api`, todas as leituras (list/retrieve/cancel/issued) ganham os 44 campos de uma vez.
*Trade-off aceito*: `raw` duplica dados já tipados — os tipados são a via preferida (documentar), `raw` é forward-compat.

### D2 — Conjunto tipado: apenas os 3 campos de ISS
`base_tax_amount`, `iss_rate`, `iss_tax_amount` (`number/double` no spec; Float no fio). O restante fica em `raw` — retenções, `provider`, `taxationType`, `location`, `approximateTax`, `externalId`, `rpsStatus`/`rpsType` etc.
*Alternativa rejeitada*: tipar tudo — 25 membros novos de baixo uso, custo de RBS/testes alto, e a migração futura para o gerado ficaria mais cara.

### D3 — `ServiceInvoiceBorrower` com ponte Hash (decisão do usuário, 2026-07-09)
```ruby
class ServiceInvoiceBorrower < Data.define(
  :id, :name, :federal_tax_number, :email, :phone_number,
  :address, :parent_id, :raw
)
  def self.from_api(payload) ... federal_tax_number: Company.stringify(payload["federalTaxNumber"]) ...

  # Ponte de compatibilidade: leituras Hash continuam funcionando.
  def [](key) = raw && raw[key]
  def dig(*keys) = raw&.dig(*keys)
end
```
- `invoice.borrower["name"]` (comportamento vivo hoje) continua funcionando via delegação ao `raw`; `invoice.borrower.name` passa a existir.
- `federal_tax_number` via `Company.stringify` (`value&.to_s`): o spec declara `integer int64`, mas o CNPJ alfanumérico (IN RFB 2.229/2024) exige String — desvio deliberado, **pinado no teste de alinhamento**.
- `address` permanece Hash cru dentro do Borrower (baixo valor de tipar agora).
- `provider` NÃO ganha DTO — 21 subcampos, acesso via `invoice.raw["provider"]`.
*Alternativas rejeitadas*: DTO puro (quebra `borrower["..."]` vivo — viola SemVer minor); manter Hash (perde ergonomia e a proteção do CNPJ alfanumérico).

### D4 — Teste de alinhamento ancorado por PATH, com tripwire de migração
Parse do `openapi/nf-servico-v1.yaml` (Psych, como `account_webhook_alignment_spec.rb`) e `dig` por `paths → /v1/companies/{company_id}/serviceinvoices/{id} → get → 200 → schema inline`.
- **NÃO ancorar por `operationId`**: `ServiceInvoices_idGet` colide (`/{id}` E `/external/{id}`).
- Asserções: (a) todo membro tipado (exceto `raw`/`pdf`/`xml`) existe no schema (subset, não igualdade — o DTO não cobre os 44); (b) **pina os fantasmas**: `pdf`/`xml` ausentes do schema (se um sync adicioná-los, remover a deprecação); (c) **pina o desvio** `borrower.federalTaxNumber` int64 vs String no DTO; (d) campos tipados do Borrower ⊆ propriedades de `borrower` no schema.
- **Tripwire de migração**: quando o upstream componentizar a resposta, o schema inline vira `$ref` e o `dig` retorna estrutura sem `properties` → o teste falha ruidosamente → migrar para o modelo gerado.

### D5 — Deprecar `pdf`/`xml`, não remover
Membros mantidos (sempre `nil` — não existem na resposta), `@deprecated` YARD apontando `ServiceInvoices#download_pdf`/`#download_xml`. Remoção na próxima major. Mantém a change **minor** (mesma lógica do `totalAmount` no PHP).

### D6 — Ordem dos membros: anexar ao fim, `:raw` por último
`base_tax_amount`, `iss_rate`, `iss_tax_amount` anexados após `modified_on`; `:raw` como último membro (convenção do `ConsumerInvoice`). Protege construção posicional hipotética e mantém `to_h`/`deconstruct` estáveis nos prefixos existentes.

### D7 — Absorver o commit do spec atualizado + código gerado (decisão do usuário, 2026-07-09)
A atualização local do `nf-servico-v1.yaml` (ErrorsResource) entra nesta change, seguindo o fluxo já exigido pelo spec `openapi-pipeline` ("commit specs and generated files together"): yaml + `rake generate` no mesmo commit, `generate:check` verde. Justificativa para agrupar aqui: a change já toca o docblock do `service_invoice.rb` que fica obsoleto, e implementá-la com o yaml desatualizado no working tree deixaria a CI vermelha no meio do caminho. O delta de `openapi-pipeline` corrige apenas o exemplo do cenário (comportamento do gerador inalterado).
*Alternativa rejeitada*: commit separado do yaml — funcionaria, mas duplicaria toques nos mesmos arquivos (docblock, README) em duas PRs contíguas.

## Risks / Trade-offs

- [`to_h`/`members` do Data ganham chaves novas] → aditivo; consumidores que fazem snapshot de `to_h` veem chaves extras — aceitável em minor, notar no CHANGELOG.
- [Ponte `#[]` pode mascarar typo de chave (retorna `nil`)] → mesmo comportamento do Hash atual; documentar que a via tipada é a preferida.
- [Schema inline pode divergir do fio real] → o spec foi validado por sonda ao vivo nas changes anteriores; validar campos novos com sonda antes de fechar (lembrete de método: grep nos `openapi/*.yaml` + probe ao vivo).

## Migration Plan

1. Implementar D1→D6 numa PR (minor), suíte `rake` completa (spec + rubocop + steep + rbs).
2. CHANGELOG coordenado com o client-php (`expand-service-invoice-dto`, v3.3.0 lá).
3. Quando o `nfe/docs` componentizar a resposta + re-sync: o teste de alinhamento quebra → migrar `ServiceInvoice` para o modelo gerado, mantendo `raw` e a ponte do Borrower como camada de compat.

## Open Questions

_(nenhuma — resolvida no apply)_

- ~~Validar ao vivo se os campos de ISS vêm com serialização inesperada~~ **Resolvida** (sonda read-only no retrieve, 2026-07-09): valores inteiros chegam como `Integer` no JSON (`issTaxAmount: 0`), decimais como `Float` (`issRate: 0.05`, `baseTaxAmount: 9.98`) → RBS do trio fixado em `(Float | Integer)?`. A mesma sonda confirmou ao vivo: fantasmas `pdf`/`xml` ausentes, Borrower com fio Integer normalizado a String pela ponte, e 21 campos sem membro tipado acessíveis via `raw`. Nota operacional: a conta 1 das sondas responde 503 em `GET /v1/companies/{id}/serviceinvoices`; a conta 2 respondeu normalmente.
