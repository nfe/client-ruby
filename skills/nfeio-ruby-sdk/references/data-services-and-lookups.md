# Consultas (CEP/CNPJ/CPF), cupom NFC-e, empresas, pessoas e certificados

## Famílias de dados e a chave

`addresses`, `legal_entity_lookup`, `natural_person_lookup` e os recursos
`*_query` pertencem às famílias **DATA** (`addresses`, `legal-entity`,
`natural-person`, `nfe-query`). Elas usam `data_api_key` e, na ausência dele,
caem em `api_key`. Configure ambas as chaves quando consumir dados:

```ruby
client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: ENV.fetch("NFE_DATA_API_KEY")   # ou deixe cair no api_key
)
```

> Lembrete: `api.nfse.io` (`:cte`) NÃO é família de dados; usa `api_key`.

## `addresses` — consulta de CEP (posicional)

Host `address.api.nfe.io/v2`. Todas retornam `Nfe::AddressLookupResponse`.

```ruby
client.addresses.lookup_by_postal_code("01310-100")   # CEP normalizado p/ 8 dígitos
client.addresses.lookup_by_term("Avenida Paulista")
client.addresses.search(filter: "...")                # OData $filter opaco
```

CEP que não vira 8 dígitos → `Nfe::InvalidRequestError`. Termo vazio idem.

## `legal_entity_lookup` — consulta CNPJ (posicional)

Host `legalentity.api.nfe.io`. CNPJ aceito em qualquer formato (normalizado p/
14 caracteres; UF case-insensitive).

```ruby
client.legal_entity_lookup.get_basic_info(cnpj, update_address: nil, update_city_code: nil)
  # => Nfe::LegalEntityBasicInfoResponse
client.legal_entity_lookup.get_state_tax_info(state, cnpj)              # => Nfe::LegalEntityStateTaxResponse
client.legal_entity_lookup.get_state_tax_for_invoice(state, cnpj)       # => ...ForInvoiceResponse
client.legal_entity_lookup.get_suggested_state_tax_for_invoice(state, cnpj)
```

CNPJ ≠ 14 ou UF inválida → `Nfe::InvalidRequestError`.

## `natural_person_lookup` — consulta CPF (posicional)

Host `naturalperson.api.nfe.io`. CPF normalizado p/ 11 dígitos; a data de
nascimento é normalizada p/ `YYYY-MM-DD` (aceita `String`/`Date`/`Time`).

```ruby
client.natural_person_lookup.get_status("123.456.789-00", "1990-05-20")
  # => Nfe::NaturalPersonStatusResponse
client.natural_person_lookup.get_status(cpf, Date.new(1990, 5, 20))   # Date também serve
```

## `consumer_invoice_query` — cupom NFC-e por chave (posicional)

Host `nfe.api.nfe.io/v1`. DISTINTO de `consumer_invoices` (emissão).

```ruby
client.consumer_invoice_query.retrieve(access_key)          # => Nfe::TaxCoupon
File.binwrite("cupom.xml", client.consumer_invoice_query.download_xml(access_key))  # bytes
```

(`product_invoice_query` está em `references/product-invoices-and-taxes.md`.)

## `companies` — empresas + certificado A1 (posicional)

Host `api.nfe.io/v1`. CRUD com **argumentos posicionais**; apaga com `remove`.

```ruby
company = client.companies.create({ name: "Acme", federalTaxNumber: "12345678000199" })
client.companies.retrieve(company.id)                  # => Nfe::Company
client.companies.update(company.id, { email: "fiscal@acme.com" })
client.companies.remove(company.id)                    # => { deleted: true, id: ... }  (NÃO #delete)
client.companies.list(page_index: 0, page_count: 100)  # page-style (0-based aqui)
client.companies.list_all                              # auto-pagina (helper, não otimizado)
client.companies.find_by_tax_number("12345678000199")  # client-side
client.companies.find_by_name("acme")
```

`create`/`update` validam client-side: `federalTaxNumber` deve ter 11 (CPF) ou
14 (CNPJ) dígitos e `email` formato válido — senão `Nfe::InvalidRequestError`
(sem coerção a Integer, sem dígito verificador).

### Certificado digital (PKCS#12 .pfx/.p12)

```ruby
# valida localmente, sem HTTP:
info = client.companies.validate_certificate(file: "/path/cert.pfx", password: "senha")

# upload (pré-valida local, depois multipart):
client.companies.upload_certificate(company.id, file: "/path/cert.pfx", password: "senha")
client.companies.replace_certificate(company.id, file: bytes, password: "senha")  # alias

status = client.companies.get_certificate_status(company.id)  # => Nfe::CertificateStatus
status.has_certificate; status.expires_on; status.days_until_expiration; status.expiring_soon

client.companies.check_certificate_expiration(company.id, threshold_days: 30)  # => Hash | nil
client.companies.get_companies_with_certificates
client.companies.get_companies_with_expiring_certificates(threshold_days: 30)
```

`file:` aceita um **path** OU os **bytes crus** do .pfx/.p12. Senha/bytes ficam
só em memória. Formato não suportado / senha errada → `Nfe::InvalidRequestError`.

## `legal_people` / `natural_people` — tomadores (posicional, escopo por empresa)

Host `api.nfe.io/v1`, sob `/companies/{id}/legalpeople` (PJ) e `/naturalpeople`
(PF). `list` retorna `Nfe::ListResponse` sem paginação (parity Node).

```ruby
client.legal_people.list(company_id)                       # => Nfe::ListResponse
client.legal_people.create(company_id, data)               # => Nfe::LegalPerson
client.legal_people.retrieve(company_id, legal_person_id)
client.legal_people.update(company_id, legal_person_id, data)
client.legal_people.delete(company_id, legal_person_id)    # => nil
client.legal_people.create_batch(company_id, [data1, data2])  # sequencial, em ordem
client.legal_people.find_by_tax_number(company_id, "12345678000199")

client.natural_people.create(company_id, data)             # => Nfe::NaturalPerson
client.natural_people.find_by_tax_number(company_id, "12345678900")  # normaliza p/ 11 dígitos
```

Objetos de valor (`Nfe::Company`, `Nfe::LegalPerson`, `Nfe::NaturalPerson`,
`Nfe::CertificateStatus`, etc.) são `Data.define` imutáveis com membros
snake_case hidratados de payloads camelCase.
