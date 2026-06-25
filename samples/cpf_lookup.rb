# frozen_string_literal: true

# Consulta de CPF (pessoa física): situação cadastral na Receita Federal.
# Requer o CPF e a data de nascimento.
#
# Usa a família de dados: prefere NFE_DATA_API_KEY, caindo para NFE_API_KEY.
#
# Pré-requisitos:
#   * NFE_API_KEY        — chave principal
#   * NFE_DATA_API_KEY   — chave de dados (opcional; cai para NFE_API_KEY)
#
# Uso:
#   ruby samples/cpf_lookup.rb [CPF] [YYYY-MM-DD]

require_relative "config"

cpf = ARGV[0] || "00000000000"
birth_date = ARGV[1] || "1990-01-31"

# get_status — (federal_tax_number, birth_date) posicionais. A data aceita
# String ISO, Date, Time ou DateTime (normalizada para YYYY-MM-DD).
status = $nfe.natural_person_lookup.get_status(cpf, birth_date)

if status.nil?
  puts "Nenhum status retornado para o CPF informado."
else
  puts "Nome: #{status.name}"
  puts "Situação: #{status.status}"
  puts "Resposta completa: #{status.inspect}"
end
