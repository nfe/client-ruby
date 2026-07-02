# frozen_string_literal: true

# Consulta de CNPJ (pessoa jurídica): dados cadastrais básicos e a inscrição
# estadual adequada para emissão.
#
# Usa a família de dados: prefere NFE_DATA_API_KEY, caindo para NFE_API_KEY.
#
# Pré-requisitos:
#   * NFE_API_KEY        — chave principal
#   * NFE_DATA_API_KEY   — chave de dados (opcional; cai para NFE_API_KEY)
#
# Uso:
#   ruby samples/cnpj_lookup.rb [CNPJ] [UF]

require_relative "config"

cnpj = ARGV[0] || "19101009000199"
state = ARGV[1] || "SP"

# Dados cadastrais básicos do CNPJ.
basic = $nfe.legal_entity_lookup.get_basic_info(cnpj)
puts "Razão social: #{basic.name}" if basic.respond_to?(:name)
puts "Resposta (basicInfo): #{basic.inspect}"

# Inscrição estadual adequada para emissão (estado + CNPJ).
state_tax = $nfe.legal_entity_lookup.get_state_tax_for_invoice(state, cnpj)
puts "Resposta (stateTaxForInvoice/#{state}): #{state_tax.inspect}"
