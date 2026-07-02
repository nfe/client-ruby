# frozen_string_literal: true

# Consulta de CEP (endereço) por código postal.
#
# Usa a família de dados: prefere NFE_DATA_API_KEY, caindo para NFE_API_KEY.
#
# Pré-requisitos:
#   * NFE_API_KEY        — chave principal
#   * NFE_DATA_API_KEY   — chave de dados (opcional; cai para NFE_API_KEY)
#
# Uso:
#   ruby samples/cep_lookup.rb [CEP]

require_relative "config"

cep = ARGV[0] || "01310-100"

# lookup_by_postal_code — aceita o CEP em qualquer formato.
result = $nfe.addresses.lookup_by_postal_code(cep)

# A resposta envolve um array de endereços em .addresses.
result.addresses.each do |address|
  city_name = address.city&.name
  puts "#{address.street}, #{address.district} — #{city_name}/#{address.state}"
end

puts "Nenhum endereço encontrado para #{cep}." if result.addresses.empty?
