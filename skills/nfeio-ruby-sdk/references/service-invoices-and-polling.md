# NFS-e (`service_invoices`) e polling

Recurso canônico de emissão da plataforma. Host `api.nfe.io` `/v1`, família
`:main`, chave `api_key`. Todos os métodos usam **keyword args**.

## Assinaturas

```ruby
client.service_invoices.create(company_id:, data:, idempotency_key: nil, request_options: nil)
  # => Nfe::Resources::ServiceInvoicePending | Nfe::Resources::ServiceInvoiceIssued
client.service_invoices.list(company_id:, **options)            # => Nfe::ListResponse (page-style)
client.service_invoices.retrieve(company_id:, invoice_id:)      # => Nfe::ServiceInvoice
client.service_invoices.cancel(company_id:, invoice_id:)        # => Nfe::ServiceInvoice (síncrono)
client.service_invoices.send_email(company_id:, invoice_id:)    # => { sent:, message: }
client.service_invoices.download_pdf(company_id:, invoice_id: nil)  # => String (bytes); nil => ZIP da empresa
client.service_invoices.download_xml(company_id:, invoice_id: nil)  # => String (bytes); nil => ZIP da empresa
client.service_invoices.get_status(company_id:, invoice_id:)    # => StatusResult
```

`list` aceita (snake_case, mapeados p/ camelCase): `page_index`, `page_count`,
`issued_begin`, `issued_end`, `created_begin`, `created_end`, `has_totals`.

`data` é um `Hash` com chaves **camelCase** (serializado como JSON cru). Campos
do DTO de leitura `Nfe::ServiceInvoice`: `id`, `flow_status`, `flow_message`,
`status`, `environment`, `rps_number`, `rps_serial_number`, `number`,
`check_code`, `issued_on`, `cancelled_on`, `amount_net`, `services_amount`,
`borrower`, `city_service_code`, `federal_service_code`, `description`,
`created_on`, `modified_on`, `base_tax_amount`, `iss_rate`, `iss_tax_amount` e
`raw` (payload completo — retenções, `provider`, `taxationType` etc. via
`invoice.raw["..."]`). `borrower` é `Nfe::ServiceInvoiceBorrower` tipado
(`federal_tax_number` sempre String; leituras Hash `borrower["..."]` seguem
funcionando). `pdf`/`xml` são fantasmas **deprecated** (sempre `nil`) — use
`download_pdf`/`download_xml`.

## Emitir + esperar (polling manual)

Não há `create_and_wait` em v1.0. Padrão recomendado:

```ruby
result = client.service_invoices.create(
  company_id: company_id,
  data: {
    cityServiceCode: "2690",
    description: "Consultoria",
    servicesAmount: 1500.0,
    borrower: {
      type: "LegalEntity",
      name: "Cliente Ltda",
      federalTaxNumber: "12345678000199",
      email: "fiscal@cliente.com"
    }
  },
  idempotency_key: SecureRandom.uuid   # opcional, mas recomendado
)

invoice =
  if result.issued?            # 201/200 — materializou na hora
    result.resource
  else                         # 202 — entrou na fila
    poll(client, company_id, result.invoice_id)
  end

def poll(client, company_id, invoice_id, max_attempts: 30, interval: 2)
  max_attempts.times do
    inv = client.service_invoices.retrieve(company_id: company_id, invoice_id: invoice_id)
    return inv if Nfe::FlowStatus.terminal?(inv.flow_status)
    sleep interval
  end
  raise "NFS-e #{invoice_id} não concluiu a tempo"
end
```

## `get_status` (atalho exclusivo de `service_invoices`)

Deriva o status de um `retrieve` (sem HTTP extra) e devolve um `StatusResult`
com predicados de conveniência:

```ruby
st = client.service_invoices.get_status(company_id: id, invoice_id: iid)
st.status      # => "Issued" (String do flow_status; "WaitingSend" se ausente)
st.invoice     # => Nfe::ServiceInvoice
st.complete?   # => Nfe::FlowStatus.terminal?(status)
st.failed?     # => status in %w[IssueFailed CancelFailed]
```

Loop equivalente baseado em `get_status`:

```ruby
loop do
  st = client.service_invoices.get_status(company_id: id, invoice_id: iid)
  break if st.complete?
  sleep 2
end
```

## Flow status

`Nfe::FlowStatus` (module_function `terminal?`):

- **TERMINAL** (para o polling): `Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`.
- **NON_TERMINAL** (continua): `PullFromCityHall`, `WaitingCalculateTaxes`,
  `WaitingDefineRpsNumber`, `WaitingSend`, `WaitingSendCancel`, `WaitingReturn`,
  `WaitingDownload`.

```ruby
Nfe::FlowStatus.terminal?(invoice.flow_status)   # => Boolean
```

## Download

`download_pdf`/`download_xml` retornam **bytes** (`ASCII-8BIT`). Passe
`invoice_id: nil` (ou omita) para baixar o **ZIP** consolidado da empresa.

```ruby
File.binwrite("nfse-#{iid}.pdf", client.service_invoices.download_pdf(company_id: id, invoice_id: iid))
File.binwrite("nfse-empresa.zip", client.service_invoices.download_pdf(company_id: id)) # ZIP
```

## Discriminação por pattern matching

```ruby
case client.service_invoices.create(company_id: id, data: payload)
in Nfe::Resources::ServiceInvoicePending(invoice_id:, location:)
  enqueue_poll(invoice_id)
in Nfe::Resources::ServiceInvoiceIssued(resource:)
  persist(resource)
end
```

`*Pending` (`invoice_id`, `location`) e `*Issued` (`resource`) são
`Data.define` imutáveis com `pending?`/`issued?`.
