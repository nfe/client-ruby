---
title: Empresas (companies) no SDK Ruby da NFE.io
sidebar_label: Empresas
sidebar_position: 7
slug: empresas
description: CRUD de empresas e ciclo de vida do certificado digital (upload, validação e status) no recurso companies do SDK Ruby da NFE.io.
---

# Empresas (`companies`)

O recurso `companies` gerencia as empresas emissoras da sua conta — CRUD completo
mais o ciclo de vida do certificado digital (upload, substituição, validação e
status). Faz parte da família `main`, servida por `api.nfe.io` (`/v1`), e usa a
`api_key`.

:::note Exclusão é `remove`, não `delete`
Para excluir uma empresa, chame `companies.remove(company_id)`. O nome evita
conflito de semântica com `delete` e mantém paridade com os SDKs Node e PHP.
:::

## Métodos públicos

```ruby
companies.create(data)                                  # => Nfe::Company
companies.list(page_index: 0, page_count: 100)          # => Nfe::ListResponse
companies.list_all                                      # => Array<Nfe::Company>
companies.list_each                                     # => Enumerator<Nfe::Company>
companies.retrieve(company_id)                          # => Nfe::Company
companies.update(company_id, data)                      # => Nfe::Company
companies.remove(company_id)                            # => { deleted: true, id: ... }
companies.find_by_tax_number(tax_number)                # => Nfe::Company | nil
companies.find_by_name(name)                            # => Array<Nfe::Company>

# Certificado digital
companies.validate_certificate(file:, password:)        # => Nfe::CertificateInfo (sem HTTP)
companies.upload_certificate(company_id, file:, password:, filename: nil)
companies.replace_certificate(company_id, file:, password:, filename: nil)
companies.get_certificate_status(company_id)            # => Nfe::CertificateStatus
companies.check_certificate_expiration(company_id, threshold_days: 30)
companies.get_companies_with_certificates               # => Array<Nfe::Company>
companies.get_companies_with_expiring_certificates(threshold_days: 30)
```

## Exemplos

### Criar e recuperar uma empresa

```ruby
require "nfe"

client = Nfe::Client.new(api_key: ENV.fetch("NFE_API_KEY"))

company = client.companies.create(
  name: "Acme Serviços LTDA",
  federalTaxNumber: "12345678000199",
  email: "fiscal@acme.com.br"
)

client.companies.retrieve(company.id)
```

:::tip Validação local de `federalTaxNumber`
`create` e `update` validam o formato de `federalTaxNumber` (11 dígitos para CPF
ou 14 para CNPJ) e o formato do `email` quando presente, levantando
`Nfe::InvalidRequestError` **antes** de qualquer requisição HTTP. Não há
verificação de dígito verificador.
:::

### Paginar e localizar empresas

```ruby
# Uma página por vez (page_index é 0-based no SDK):
page = client.companies.list(page_index: 0, page_count: 50)
page.data.each { |c| puts c.name }

# Todas as empresas (auto-paginação) ou stream preguiçoso:
client.companies.list_all
client.companies.list_each.each { |c| puts c.id }

# Buscas auxiliares (filtragem no cliente):
client.companies.find_by_tax_number("12.345.678/0001-99")
client.companies.find_by_name("acme")
```

:::warning Helpers de busca não são otimizados
`find_by_tax_number`, `find_by_name`, `list_all`, `get_companies_with_certificates`
e `get_companies_with_expiring_certificates` percorrem **todas** as páginas e
filtram no cliente. Evite em contas com muitas empresas.
:::

### Validar e enviar o certificado digital

```ruby
# Validação puramente local (não faz HTTP): confere senha e DER.
info = client.companies.validate_certificate(
  file: "/caminho/certificado.pfx",
  password: ENV.fetch("CERT_PASSWORD")
)

# Upload: pré-valida localmente (fail-fast) e então envia multipart/form-data.
client.companies.upload_certificate(
  company.id,
  file: "/caminho/certificado.pfx",
  password: ENV.fetch("CERT_PASSWORD"),
  filename: "certificado.pfx"
)

# Status e alerta de expiração:
status = client.companies.get_certificate_status(company.id)
status.days_until_expiration

client.companies.check_certificate_expiration(company.id, threshold_days: 30)
```

:::note Apenas `.pfx` e `.p12`
Quando você informa `filename:`, o SDK rejeita extensões diferentes de `.pfx` e
`.p12` com `Nfe::InvalidRequestError`. O parâmetro `file:` aceita um caminho de
arquivo ou os bytes brutos do certificado.
:::

## Veja também

- [Pessoas jurídicas](./legal-people.md) e [Pessoas físicas](./natural-people.md) — tomadores vinculados à empresa.
- [Webhooks](./webhooks.md) — eventos por empresa.
- [Tratamento de erros](../errors.md).
