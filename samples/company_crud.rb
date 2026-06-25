# frozen_string_literal: true

# Ciclo completo de empresa (company): create, list, retrieve, update, remove.
#
# ATENÇÃO: este exemplo CRIA e depois REMOVE uma empresa. Rode apenas em uma
# conta de testes.
#
# Pré-requisitos:
#   * NFE_API_KEY — chave principal
#
# Uso:
#   ruby samples/company_crud.rb

require_relative "config"

# create — recebe um Hash posicional com chaves camelCase.
company = $nfe.companies.create(
  name: "Empresa Exemplo SDK",
  tradeName: "Exemplo SDK",
  federalTaxNumber: "19101009000199",
  email: "contato@exemplo-sdk.com.br",
  address: {
    country: "BRA",
    postalCode: "01310-100",
    street: "Avenida Paulista",
    number: "1000",
    district: "Bela Vista",
    city: { code: "3550308", name: "São Paulo" },
    state: "SP"
  }
)
puts "Criada: #{company.id} — #{company.name}"

# list — paginada por página (page_index é 0-based).
page = $nfe.companies.list(page_index: 0, page_count: 10)
puts "Empresas na primeira página: #{page.data.size}"

# retrieve — id posicional.
fetched = $nfe.companies.retrieve(company.id)
puts "Recuperada: #{fetched.id} — #{fetched.name}"

# update — id + Hash posicionais.
updated = $nfe.companies.update(company.id, { tradeName: "Exemplo SDK (atualizado)" })
puts "Atualizada: tradeName=#{updated.trade_name}"

# remove — note o nome `remove` (não `delete`).
removed = $nfe.companies.remove(company.id)
puts "Removida: #{removed.inspect}"
