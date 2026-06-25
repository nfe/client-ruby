# Guia de migração — `0.x` → `1.0`

> ⚠️ A `v1.0.0` é uma **reescrita greenfield com quebra total de compatibilidade**.
> Nenhum símbolo da série `0.x` foi mantido. A `0.x` está congelada no branch
> `0.x-legacy` (sem backports). Migre de forma deliberada.

## Visão geral

| Tema | `0.x` (legado) | `1.0` |
|---|---|---|
| Entrada | API global: `Nfe.api_key("...")` (método setter) + estado por classe | Cliente único: `Nfe::Client.new(api_key: "...")` |
| Configuração | `Nfe.configure { \|c\| c.url = ... }` | `Nfe::Client.new(api_key:, data_api_key:, environment:, timeout:, ...)` |
| Escopo de empresa | `Nfe::ServiceInvoice.company_id("...")` (estado por classe) | `company_id:` por chamada (`client.service_invoices.create(company_id:, data:)`) |
| HTTP | dependência `rest-client` | zero deps — `Net::HTTP` da stdlib |
| Modelos | `NfeObject` dinâmico (`method_missing`) | value objects imutáveis (`Data.define`), `snake_case` |
| Ruby | 2.x | 3.2+ |
| Erros | string global `last_api_response_code` / exceções genéricas | hierarquia tipada sob `Nfe::Error` |
| Downloads | `invoice.download(id, :pdf).body` | `String` binária (bytes crus) retornada pelo método de download |

## Exemplos

### Definição de chave e emissão

```ruby
# 0.x
Nfe.api_key("c73d49f9649046eeba36dcf69f6334fd")
Nfe::ServiceInvoice.company_id("55df4dc6b6cd9007e4f13ee8")
Nfe::ServiceInvoice.create(customer_params.merge(service_params))

# 1.0
client = Nfe::Client.new(api_key: "c73d49f9649046eeba36dcf69f6334fd")
client.service_invoices.create(company_id: "55df4dc6b6cd9007e4f13ee8", data: { ... })
```

### Cancelamento

```ruby
# 0.x
Nfe::ServiceInvoice.cancel("59443a0e2a8b6806986d7a2d")

# 1.0
client.service_invoices.cancel(company_id: "55df...", invoice_id: "59443a0e2a8b6806986d7a2d")
```

### Download em PDF

```ruby
# 0.x
Nfe::ServiceInvoice.download("59443a0e2a8b6806986d7a2d", :pdf).body

# 1.0 — retorna a String binária (bytes), pronta para File.binwrite / send_data
bytes = client.service_invoices.download_pdf(company_id: "55df...", invoice_id: "59443a...")
```

## Notas

- **Sem backports** para a `0.x`. Correções e novos recursos só na `1.0+`.
- **Verificação de webhook** muda de esquema na `1.0`; o exemplo legado
  (`X-NFEIO-Signature` + Base64) **não** corresponde ao SDK `1.0` — consulte a
  documentação atualizada.
- Esta seção será expandida conforme as etapas da `v1` forem entregues.
