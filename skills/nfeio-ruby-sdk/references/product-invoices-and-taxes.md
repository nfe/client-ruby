# NF-e, NFC-e, CT-e inbound, state_taxes, tax_codes e tax_calculation

Recursos da família `:cte` (host `api.nfse.io`, paths com `/v2`) + a consulta
`product_invoice_query` (host `nfe.api.nfe.io`). A família `:cte` usa `api_key`
(NÃO é família de dados). Recursos de emissão usam **keyword args**.

## `product_invoices` — NF-e (mod 55)

```ruby
client.product_invoices.create(company_id:, data:, idempotency_key: nil, request_options: nil)
client.product_invoices.create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)
client.product_invoices.list(company_id:, environment:, **options)   # environment OBRIGATÓRIO
client.product_invoices.retrieve(company_id:, invoice_id:)           # => Nfe::ProductInvoice
client.product_invoices.cancel(company_id:, invoice_id:, reason: nil)# => Hash (async)
client.product_invoices.list_items(company_id:, invoice_id:, limit: nil, starting_after: nil)
client.product_invoices.list_events(company_id:, invoice_id:, limit: nil, starting_after: nil)
client.product_invoices.send_correction_letter(company_id:, invoice_id:, reason:)  # reason 15..1000
client.product_invoices.disable(company_id:, invoice_id:, reason: nil)
client.product_invoices.disable_range(company_id:, data:)
# downloads => Nfe::NfeFileResource (URI, NÃO bytes):
client.product_invoices.download_pdf(company_id:, invoice_id:, force: nil)
client.product_invoices.download_xml(company_id:, invoice_id:)
client.product_invoices.download_rejection_xml(company_id:, invoice_id:)
client.product_invoices.download_epec_xml(company_id:, invoice_id:)
client.product_invoices.download_correction_letter_pdf(company_id:, invoice_id:)
client.product_invoices.download_correction_letter_xml(company_id:, invoice_id:)
```

`create`/`create_with_state_tax` retornam `ProductInvoicePending` (202, comum —
conclusão chega por **webhook**) ou `ProductInvoiceIssued` (201). Faça polling
com `retrieve` + `Nfe::FlowStatus.terminal?`, ou trate o webhook
`product_invoice.issued` (filtros reais via `webhooks.fetch_event_types`).

```ruby
res = client.product_invoices.create(company_id: id, data: nfe_payload)
res.invoice_id if res.pending?   # 202 — acompanhe via webhook/polling
```

`list` (cursor-style) **exige** `environment:` String (`"Production"`/`"Test"`),
senão levanta `Nfe::InvalidRequestError`. Options: `starting_after`,
`ending_before`, `limit`, `q`.

```ruby
page = client.product_invoices.list(company_id: id, environment: "Production", limit: 50)
page.each { |nfe| ... }                  # ListResponse é Enumerable
page.page.starting_after                 # cursor
```

### Downloads de NF-e retornam URI (não bytes)

```ruby
file = client.product_invoices.download_pdf(company_id: id, invoice_id: iid)
file.uri          # baixe a partir desta URI
file.content_type # "application/pdf", quando informado
```

### Carta de correção (CC-e)

`reason` deve ter **15 a 1000 caracteres** (sem acentos), validado client-side
ANTES de qualquer HTTP — fora do range levanta `Nfe::InvalidRequestError`.

```ruby
client.product_invoices.send_correction_letter(
  company_id: id, invoice_id: iid,
  reason: "Correcao do endereco de entrega do destinatario"   # >= 15 chars
)
```

### Inutilização

```ruby
client.product_invoices.disable(company_id: id, invoice_id: iid, reason: "Erro de digitacao")
client.product_invoices.disable_range(company_id: id, data: {
  environment: "Production", serie: 1, state: "SP",
  beginNumber: 100, lastNumber: 110, reason: "Salto de numeracao"   # camelCase no Hash
})
```

## `consumer_invoices` — NFC-e

Emissão NFC-e (parity-plus: o SDK Node não tem). Mesma forma de `create`/`list`/
`retrieve`/`cancel`/`list_items`/`list_events`/`disable_range`, MAS:

- **downloads retornam BYTES** (`download_pdf`, `download_xml`,
  `download_rejection_xml`), diferente de `product_invoices`.
- **NÃO** existem `send_correction_letter` (CC-e não se aplica a NFC-e),
  `download_epec_xml`, nem `disable` por nota — só `disable_range` (inutilização
  coletiva). Chamar os ausentes → `NoMethodError`.

```ruby
File.binwrite("nfce.pdf", client.consumer_invoices.download_pdf(company_id: id, invoice_id: iid))
```

## CT-e e NF-e recebidas (inbound)

`transportation_invoices` (CT-e) e `inbound_product_invoices` (NF-e de
fornecedor) NÃO são emissão — gerenciam a busca automática via Distribuição DFe
e leem documentos por **chave de acesso de 44 dígitos**. Não têm contrato 202.

```ruby
client.transportation_invoices.enable(company_id: id)            # liga auto-fetch
cte = client.transportation_invoices.retrieve(company_id: id, access_key: "3524...7890")
File.binwrite("cte.xml", client.transportation_invoices.download_xml(company_id: id, access_key: key))

client.inbound_product_invoices.enable_auto_fetch(company_id: id, webhook_version: "2")
det = client.inbound_product_invoices.get_product_invoice_details(company_id: id, access_key: key)
client.inbound_product_invoices.manifest(company_id: id, access_key: key)  # tp_event padrão = Ciência (210210)
```

Constantes de manifesto: `MANIFEST_AWARENESS` (210210, padrão),
`MANIFEST_CONFIRMATION` (210220), `MANIFEST_NOT_PERFORMED` (210240).
Downloads inbound (`download_xml`, `get_xml`, `get_pdf`, `download_event_xml`)
retornam **bytes**.

## `product_invoice_query` — consulta NF-e por chave

Host `nfe.api.nfe.io` (família de dados `nfe_query`, usa `data_api_key`).
Argumento **posicional** (a chave de acesso):

```ruby
client.product_invoice_query.retrieve(access_key)        # => Nfe::ProductInvoiceDetails
client.product_invoice_query.list_events(access_key)     # => Nfe::ProductInvoiceEventsResponse
File.binwrite("nfe.pdf", client.product_invoice_query.download_pdf(access_key))  # bytes
File.binwrite("nfe.xml", client.product_invoice_query.download_xml(access_key))  # bytes
```

## `state_taxes` — Inscrição Estadual (CRUD, posicional)

```ruby
client.state_taxes.list(company_id, starting_after: nil, ending_before: nil, limit: nil)  # cursor
client.state_taxes.create(company_id, { code: "SP", taxNumber: "1234567890" })
client.state_taxes.retrieve(company_id, state_tax_id)
client.state_taxes.update(company_id, state_tax_id, data)
client.state_taxes.delete(company_id, state_tax_id)   # => nil
```

O `state_tax_id` retornado alimenta `product_invoices.create_with_state_tax`.

## `tax_codes` — tabelas de referência CT-e (page-style)

Retornam `Nfe::TaxCodePaginatedResponse` (page-style 1-based, NÃO `ListResponse`):

```ruby
client.tax_codes.list_operation_codes(page_index: 1, page_count: 50)
client.tax_codes.list_acquisition_purposes
client.tax_codes.list_issuer_tax_profiles
client.tax_codes.list_recipient_tax_profiles
```

## `tax_calculation` — motor de impostos (posicional)

```ruby
resp = client.tax_calculation.calculate(tenant_id, {
  operationType: "...",          # operation_type ou operationType (obrigatório)
  items: [ { ... } ]             # Array não vazio (obrigatório)
})
# => Nfe::Generated::CalculoImpostosV1::CalculateResponse
```

Validação client-side: `tenant_id` não vazio + `request` Hash com
`operation_type`/`operationType` e `items` Array não vazio; senão
`Nfe::InvalidRequestError` (sem HTTP). Para type-safety, monte o `request` a
partir de `Nfe::Generated::CalculoImpostosV1::CalculateRequest#to_h`.
