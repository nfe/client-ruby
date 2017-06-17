[![Build Status](https://travis-ci.org/nfe/client-ruby.svg?branch=master)](https://travis-ci.org/nfe/client-ruby.svg?branch=master)

# NFe.io para Ruby

## Instalação

Incluir essa linha no Gemfile da sua aplicação:

```ruby
gem 'nfe-io'
```

E depois execute:

    $ bundle

Ou instale diretamente via comando:

    $ gem install nfe-io

## Exemplos de uso

### Emitir nota fiscal

```ruby
# Define a API Key, conforme está no painel
Nfe.api_key('c73d49f9649046eeba36dcf69f6334fd')

# ID da empresa, você encontra no painel
Nfe::ServiceInvoice.company_id("55df4dc6b6cd9007e4f13ee8")

# Dados do Tomador dos Serviços
customer_params = {
  borrower: {
    federalTaxNumber: '191', # CNPJ ou CPF (opcional para tomadores no exterior)
    name: 'BANCO DO BRASIL SA', # Nome da pessoa física ou Razão Social da Empresa
    email: 'nfe-io@mailinator.com', # Email para onde deverá ser enviado a nota fiscal
    # Endereço do tomador
    address: {
      country: 'BRA', # Código do pais com três letras
      postalCode: '70073901', # CEP do endereço (opcional para tomadores no exterior)
      street: 'Rua Do Cliente', # Logradouro
      number: 'S/N', # Número (opcional)
      additionalInformation: 'QUADRA 01 BLOCO G', # Complemento (opcional)
      district: 'Asa Sul', # Bairro
      city: { # Cidade é opcional para tomadores no exterior
        code: 4204202, # Código do IBGE para a Cidade
        name: 'Brasilia' # Nome da Cidade
      },
      state: 'DF'
    }
  }
}

# Dados da nota fiscal de serviço
service_params = {
  cityServiceCode: '2690', # Código do serviço de acordo com o a cidade
  description: 'Teste, para manutenção e suporte técnico.', # Descrição dos serviços prestados
  servicesAmount: 0.1 # Valor total do serviços
}

# Emite a nota fiscal
invoice_create_result = Nfe::ServiceInvoice.create(customer_params.merge(service_params))
```

### Download da Nota Fiscal

```ruby
# Define a API Key, conforme está no painel
Nfe.api_key('c73d49f9649046eeba36dcf69f6334fd')
# ID da empresa, você encontra no painel
Nfe::ServiceInvoice.company_id("55df4dc6b6cd9007e4f13ee8")
# Os formatos suportados são :pdf e :xml, e o primeiro parâmetro é o ID da nota
invoice = Nfe::ServiceInvoice.download("59443a0e2a8b6806986d7a2d", :pdf)
# O conteúdo do PDF/XML pode ser acessado da seguinte forma
invoice.body
# Caso você esteja utilizando Rails, pode usar o método send_data para retornar
# o conteúdo da Nota Fiscal diretamente para o usuário
# Note que neste caso o arquivo é o PDF, mas poderia ser o XML, mude se necessário
send_data(invoice.body, filename: 'invoice.pdf', type: 'application/pdf')
```

## Contribuir

Envio de bugs e pull requests são muito bem vindos no https://github.com/nfe/client-ruby.

### Como atualizar o pacote

- Alterar versão do pacote no arquivo /lib/nfe/version.rb
- Comitar nova versão, com uma descrição como abaixo

```bash
git add lib/nfe/version.rb
git commit -m 'Bump version 0.3.0'
```
- Criar git tag

```bash
git tag 0.3.0
```

- Executar gem build, repare que um novo arquivo será criado, com a versão do pacote alterada acima

```bash
gem build nfe.gemspec
```

- Executar gem push do pacote gem criado

```ruby
gem push nfe-io-0.3.0.gem
```

## License

Originalmente criado pela equipe da [Pluga](https://github.com/PlugaDotCo).

Esta gem é open source sob os termos da [Licença MIT](http://opensource.org/licenses/MIT).
