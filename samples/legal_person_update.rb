# frozen_string_literal: true

# Atualiza uma pessoa jurídica (legal person) existente.
#
# Pré-requisitos:
#   * NFE_API_KEY        — chave principal
#   * NFE_COMPANY_ID     — empresa de testes
#   * NFE_LEGAL_PERSON_ID — id da pessoa jurídica (ex.: do legal_person_create.rb)
#
# Uso:
#   NFE_LEGAL_PERSON_ID=<id> ruby samples/legal_person_update.rb

require_relative "config"

abort "Defina NFE_COMPANY_ID." if $company_id.nil?

legal_person_id = ENV["NFE_LEGAL_PERSON_ID"]
abort "Defina NFE_LEGAL_PERSON_ID (rode legal_person_create.rb primeiro)." if legal_person_id.nil?

# update — (company_id, legal_person_id, data) posicionais; data em camelCase.
updated = $nfe.legal_people.update($company_id, legal_person_id, {
  email: "novo-contato@fornecedor-exemplo.com.br"
})

puts "Pessoa jurídica atualizada: #{updated.id}"
puts "Novo e-mail: #{updated.email}"
