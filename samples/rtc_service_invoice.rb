# frozen_string_literal: true

# Emite uma NFS-e no layout RTC (Reforma Tributária do Consumo) e acompanha o
# processamento via polling manual.
#
# O RTC usa o MESMO endpoint da NFS-e clássica. Não há header/parâmetro
# discriminador: a API seleciona o layout RTC pela PRESENÇA do grupo `ibsCbs`
# no payload de criação.
#
# Pré-requisitos:
#   * NFE_API_KEY    — chave principal
#   * NFE_COMPANY_ID — empresa de testes habilitada para RTC
#
# Uso:
#   ruby samples/rtc_service_invoice.rb

require_relative "config"

abort "Defina NFE_COMPANY_ID para emitir a NFS-e RTC." if $company_id.nil?

# Payload em camelCase. A presença do grupo `ibsCbs` seleciona o layout RTC.
payload = {
  cityServiceCode: "2690",
  description: "Serviço com tributação RTC (IBS/CBS).",
  servicesAmount: 100.0,
  borrower: {
    type: "LegalEntity",
    name: "Cliente Exemplo LTDA",
    federalTaxNumber: "19101009000199",
    email: "financeiro@cliente-exemplo.com.br",
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
  # Grupo RTC: indicador de operação + classe tributária do IBS/CBS.
  ibsCbs: {
    operationIndicator: 1,
    classCode: "000001"
  }
}

result = $nfe.service_invoices_rtc.create(company_id: $company_id, data: payload)

if result.issued?
  invoice = result.resource
  puts "NFS-e RTC emitida imediatamente: #{invoice.id} (status #{invoice.flow_status})"
else
  invoice_id = result.invoice_id
  puts "NFS-e RTC em processamento (202): #{invoice_id}"
  puts "Location: #{result.location}"

  # Polling manual: retrieve até flow_status terminal.
  invoice = nil
  60.times do
    invoice = $nfe.service_invoices_rtc.retrieve(company_id: $company_id, invoice_id: invoice_id)
    puts "  flow_status=#{invoice.flow_status}"
    break if Nfe::FlowStatus.terminal?(invoice.flow_status)

    sleep 3
  end

  unless invoice && Nfe::FlowStatus.terminal?(invoice.flow_status)
    abort "Tempo de processamento esgotado; consulte mais tarde."
  end
end

puts "Status final: #{invoice.flow_status}"
