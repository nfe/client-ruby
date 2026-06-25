# frozen_string_literal: true

# Cria uma pessoa jurídica (legal person) escopada a uma empresa.
#
# Pré-requisitos:
#   * NFE_API_KEY    — chave principal
#   * NFE_COMPANY_ID — empresa de testes
#
# Uso:
#   ruby samples/legal_person_create.rb

require_relative "config"

abort "Defina NFE_COMPANY_ID." if $company_id.nil?

# create — (company_id, data) posicionais; data em camelCase.
person = $nfe.legal_people.create($company_id, {
  name: "Fornecedor Exemplo LTDA",
  federalTaxNumber: "19101009000199",
  email: "contato@fornecedor-exemplo.com.br",
  address: {
    country: "BRA",
    postalCode: "01310-100",
    street: "Avenida Paulista",
    number: "1000",
    district: "Bela Vista",
    city: { code: "3550308", name: "São Paulo" },
    state: "SP"
  }
})

puts "Pessoa jurídica criada: #{person.id} — #{person.name}"
puts "Guarde o id para atualizar depois: #{person.id}"
