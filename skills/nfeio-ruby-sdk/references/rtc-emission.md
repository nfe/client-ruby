# Emissão RTC — Reforma Tributária do Consumo (IBS / CBS / IS)

Dois addons "parity-plus" (além dos 17 recursos canônicos compartilhados com os
SDKs PHP/Node): `service_invoices_rtc` (NFS-e) e `product_invoices_rtc`
(NF-e mod 55 / NFC-e mod 65). Use-os quando precisar dos campos da Reforma
(IBS/CBS/IS) e/ou dos DTOs RTC hidratados na resposta.

## Princípio central: layout selecionado pelo PAYLOAD

Os recursos RTC compartilham **os mesmos endpoints** dos clássicos. **Não há**
header nem query param discriminador. A API escolhe o layout RTC pela
**presença de um grupo no payload**:

- **NFS-e RTC** (`service_invoices_rtc`): presença do grupo **`ibsCbs`** no topo
  do `data`. Ausente → cai no layout NFS-e clássico.
- **NF-e/NFC-e RTC** (`product_invoices_rtc`): presença do grupo
  **`IBSCBS`** por item (`items[].tax.IBSCBS`). NF-e (55) vs NFC-e (65) também é
  inferido pela forma do payload.

`data` é sempre um `Hash` com chaves **camelCase** (JSON cru). Os DTOs gerados
(`Nfe::Generated::ServiceInvoiceRtcV1::*`, `Nfe::Generated::ProductInvoiceRtcV1::*`)
documentam a **forma** esperada, mas **não** são aceitos como entrada: eles só
deserializam (`from_api`) e não têm re-serializador camelCase — passar o objeto
emitiria chaves erradas.

## `service_invoices_rtc` — NFS-e RTC (host api.nfe.io `/v1`)

```ruby
client.service_invoices_rtc.create(company_id:, data:, idempotency_key: nil, request_options: nil)
  # => ServiceInvoiceRtcPending (202) | ServiceInvoiceRtcIssued (201; resource => Nfe::ServiceInvoice)
client.service_invoices_rtc.retrieve(company_id:, invoice_id:)              # => Nfe::ServiceInvoice
client.service_invoices_rtc.cancel(company_id:, invoice_id:)                # => Nfe::ServiceInvoice
client.service_invoices_rtc.download_cancellation_xml(company_id:, invoice_id:)  # => bytes (ADN, após Cancelled)
```

Exemplo (o grupo `ibsCbs` é o que ativa o RTC):

```ruby
result = client.service_invoices_rtc.create(
  company_id: id,
  data: {
    borrower: { type: "LegalEntity", name: "Cliente Ltda", federalTaxNumber: "12345678000199" },
    servicesAmount: 100.0,
    ibsCbs: {
      cbs: { /* ... */ },
      ibs: { /* ... */ }
    }
  },
  idempotency_key: SecureRandom.uuid
)

invoice =
  if result.issued?
    result.resource                       # Nfe::ServiceInvoice
  else
    poll_until_terminal(client.service_invoices_rtc, id, result.invoice_id)
  end
```

`download_cancellation_xml` é exclusivo do RTC de serviço: retorna **bytes** do
XML de cancelamento (ADN), disponível só após o estado `Cancelled`; indisponível
→ `Nfe::NotFoundError`.

## `product_invoices_rtc` — NF-e/NFC-e RTC (host api.nfse.io `/v2`)

Mesma superfície do `product_invoices` clássico, mas hidrata os DTOs RTC:

```ruby
client.product_invoices_rtc.create(company_id:, data:, idempotency_key: nil, request_options: nil)
client.product_invoices_rtc.create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)
client.product_invoices_rtc.list(company_id:, environment:, starting_after: nil, ending_before: nil, limit: nil, q: nil)
client.product_invoices_rtc.retrieve(company_id:, invoice_id:)   # => Generated::ProductInvoiceRtcV1::InvoiceResource
client.product_invoices_rtc.cancel(company_id:, invoice_id:, reason: nil)
client.product_invoices_rtc.list_items(company_id:, invoice_id:)
client.product_invoices_rtc.list_events(company_id:, invoice_id:)
client.product_invoices_rtc.send_correction_letter(company_id:, invoice_id:, reason:)   # reason 15..1000
client.product_invoices_rtc.disable(company_id:, invoice_id:, reason: nil)
client.product_invoices_rtc.disable_range(company_id:, data:)
# downloads => Nfe::NfeFileResource (URI, NÃO bytes):
client.product_invoices_rtc.download_pdf(company_id:, invoice_id:, force: false)
client.product_invoices_rtc.download_xml(company_id:, invoice_id:)
client.product_invoices_rtc.download_rejection_xml(company_id:, invoice_id:)
client.product_invoices_rtc.download_epec_xml(company_id:, invoice_id:)
client.product_invoices_rtc.download_correction_letter_pdf(company_id:, invoice_id:)
client.product_invoices_rtc.download_correction_letter_xml(company_id:, invoice_id:)
```

Diferenças de hidratação vs o recurso clássico:

- `retrieve`/`list`/`*Issued.resource` → `Generated::ProductInvoiceRtcV1::InvoiceResource`.
- `cancel`/`send_correction_letter` → `...::RequestCancellationResource`.
- `disable`/`disable_range` → `...::DisablementResource`.
- `list_items`/`list_events` → `...::InvoiceItemsResource` / `...::InvoiceEventsResource`.

Exemplo (o grupo `IBSCBS` por item ativa o RTC):

```ruby
result = client.product_invoices_rtc.create(
  company_id: id,
  data: {
    buyer: { /* ... */ },
    items: [
      { code: "001", description: "Produto", quantity: 1, unitAmount: 50.0,
        tax: { IBSCBS: { /* ... */ } } }   # presença de IBSCBS => layout RTC
    ]
  }
)
result.pending? ? result.invoice_id : result.resource
```

`list` (cursor-style) **exige** `environment:` String (`"Production"`/`"Test"`).
Downloads retornam `Nfe::NfeFileResource` (`.uri`), igual ao clássico.

## Polling RTC

Idêntico ao fluxo padrão — `*Pending`/`*Issued` com `pending?`/`issued?`, e
`Nfe::FlowStatus.terminal?` decide quando parar:

```ruby
def poll_until_terminal(resource, company_id, invoice_id, interval: 2, max: 30)
  max.times do
    inv = resource.retrieve(company_id: company_id, invoice_id: invoice_id)
    status = inv.respond_to?(:flow_status) ? inv.flow_status : inv&.flowStatus
    return inv if Nfe::FlowStatus.terminal?(status)
    sleep interval
  end
  raise "RTC #{invoice_id} não concluiu a tempo"
end
```

Para NF-e (mod 55) a conclusão normalmente chega por **webhook** — combine
`product_invoice.issued`/`product_invoice.issued_error` (filtros reais via
`webhooks.fetch_event_types`) com o polling acima como fallback. CC-e segue a
regra de **15..1000 caracteres**, validada client-side.
