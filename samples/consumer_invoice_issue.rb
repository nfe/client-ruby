# frozen_string_literal: true

# Emite uma NFC-e (nota fiscal de consumidor) e trata o resultado
# discriminado (pendente x emitida). Útil para PDV e e-commerce.
#
# Pré-requisitos:
#   * NFE_API_KEY    — chave principal
#   * NFE_COMPANY_ID — empresa de testes habilitada para NFC-e
#
# Uso:
#   ruby samples/consumer_invoice_issue.rb

require_relative "config"
require "securerandom"

abort "Defina NFE_COMPANY_ID para emitir a NFC-e." if $company_id.nil?

# Payload em camelCase. Exemplo mínimo: ambiente de testes, um item e
# pagamento à vista. Ajuste para a operação real.
payload = {
  id: SecureRandom.uuid,
  environmentType: "Test",
  items: [
    {
      code: "001",
      description: "Produto de balcão",
      ncm: "21069090",
      cfop: "5102",
      unit: "UN",
      quantity: 1.0,
      unitAmount: 9.90,
      totalAmount: 9.90
    }
  ],
  payment: [
    { method: "Cash", amount: 9.90 }
  ]
}

result = $nfe.consumer_invoices.create(company_id: $company_id, data: payload)

# Discriminação por pattern matching (também há result.pending?/result.issued?).
case result
in Nfe::Resources::ConsumerInvoiceIssued => issued
  invoice = issued.resource
  puts "NFC-e emitida: #{invoice.id} (status #{invoice.flow_status})"
in Nfe::Resources::ConsumerInvoicePending => pending
  puts "NFC-e em processamento (202): #{pending.invoice_id}"
  puts "Location: #{pending.location}"
  puts "Acompanhe com $nfe.consumer_invoices.retrieve(...)."
end
