# frozen_string_literal: true

# Executa o motor de cálculo de impostos para um tenant sobre uma requisição
# com um ou mais itens.
#
# Pré-requisitos:
#   * NFE_API_KEY — chave principal (a família :cte usa a chave principal)
#   * NFE_TENANT_ID — identificador do tenant (passe como 1º argumento)
#
# Uso:
#   ruby samples/tax_calculation.rb <tenant_id>

require_relative "config"

tenant_id = ARGV[0] || ENV["NFE_TENANT_ID"]
abort "Informe o tenant_id: ruby samples/tax_calculation.rb <tenant_id>" if tenant_id.nil?

# A requisição é um Hash. Validação client-side (fail-fast, sem HTTP):
# precisa conter operation_type (ou operationType) e items (Array não vazio).
request = {
  operationType: "Sale",
  items: [
    {
      code: "001",
      description: "Produto de exemplo",
      ncm: "84713012",
      cfop: "5102",
      quantity: 1.0,
      unitAmount: 100.0,
      totalAmount: 100.0,
      origin: "0"
    }
  ]
}

# calculate — (tenant_id, request) posicionais.
result = $nfe.tax_calculation.calculate(tenant_id, request)

puts "Resposta do cálculo:"
puts result.inspect
