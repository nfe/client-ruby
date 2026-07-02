# frozen_string_literal: true

# Emite uma NF-e (nota fiscal de produto). A emissão é assíncrona (HTTP 202):
# a conclusão chega via webhook (veja samples/webhook_verify.rb). Este exemplo
# dispara a emissão e imprime o id para você acompanhar.
#
# Observação: para NF-e os métodos download_* retornam um Nfe::NfeFileResource
# (um objeto com a URI do arquivo), e NÃO os bytes do arquivo.
#
# Pré-requisitos:
#   * NFE_API_KEY    — chave principal
#   * NFE_COMPANY_ID — empresa de testes habilitada para NF-e
#
# Uso:
#   ruby samples/product_invoice_issue.rb

require_relative "config"
require "securerandom"

abort "Defina NFE_COMPANY_ID para emitir a NF-e." if $company_id.nil?

# Payload em camelCase. Exemplo mínimo: ambiente de testes, um destinatário e
# um item. Ajuste para a operação fiscal real da sua empresa.
payload = {
  id: SecureRandom.uuid,
  operationNature: "Venda de mercadoria",
  environmentType: "Test",
  buyer: {
    type: "LegalEntity",
    name: "Cliente Exemplo LTDA",
    federalTaxNumber: "19101009000199",
    email: "compras@cliente-exemplo.com.br",
    address: {
      country: "BRA",
      postalCode: "01310-100",
      street: "Avenida Paulista",
      number: "1000",
      district: "Bela Vista",
      city: { code: "3550308", name: "São Paulo" },
      state: "SP"
    }
  },
  items: [
    {
      code: "001",
      description: "Produto de exemplo",
      ncm: "84713012",
      cfop: "5102",
      unit: "UN",
      quantity: 1.0,
      unitAmount: 100.0,
      totalAmount: 100.0
    }
  ]
}

result = $nfe.product_invoices.create(company_id: $company_id, data: payload)

if result.issued?
  invoice = result.resource
  puts "NF-e emitida imediatamente: #{invoice.id} (status #{invoice.flow_status})"
else
  puts "NF-e em processamento (202): #{result.invoice_id}"
  puts "Location: #{result.location}"
  puts "A conclusão será notificada por webhook. Acompanhe com:"
  puts "  $nfe.product_invoices.retrieve(company_id: ..., invoice_id: \"#{result.invoice_id}\")"
end
