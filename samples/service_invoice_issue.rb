# frozen_string_literal: true

# Emite uma NFS-e (nota fiscal de serviço), acompanha o processamento
# assíncrono via polling manual e baixa o PDF.
#
# Pré-requisitos:
#   * NFE_API_KEY    — chave principal
#   * NFE_COMPANY_ID — empresa de testes com certificado válido e habilitada
#                      para NFS-e na prefeitura
#
# Uso:
#   ruby samples/service_invoice_issue.rb

require_relative "config"

abort "Defina NFE_COMPANY_ID para emitir a NFS-e." if $company_id.nil?

# Payload em camelCase, como a API espera. Ajuste os valores para a sua
# empresa/cidade. Este é um exemplo mínimo de tomador + serviço.
payload = {
  cityServiceCode: "2690",
  description: "Desenvolvimento de software sob encomenda.",
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
  }
}

result = $nfe.service_invoices.create(company_id: $company_id, data: payload)

# A emissão é discriminada: pendente (202, assíncrona) ou já emitida (201).
if result.issued?
  invoice = result.resource
  puts "NFS-e emitida imediatamente: #{invoice.id} (status #{invoice.flow_status})"
else
  invoice_id = result.invoice_id
  puts "NFS-e em processamento (202): #{invoice_id}"
  puts "Location: #{result.location}"

  # Polling manual: consulta retrieve até o flow_status ficar terminal.
  invoice = nil
  60.times do
    invoice = $nfe.service_invoices.retrieve(company_id: $company_id, invoice_id: invoice_id)
    puts "  flow_status=#{invoice.flow_status}"
    break if Nfe::FlowStatus.terminal?(invoice.flow_status)

    sleep 3
  end

  unless invoice && Nfe::FlowStatus.terminal?(invoice.flow_status)
    abort "Tempo de processamento esgotado; tente consultar mais tarde."
  end
end

abort "Emissão falhou: flow_status=#{invoice.flow_status}" if invoice.flow_status != "Issued"

# Baixa o PDF (bytes binários ASCII-8BIT) e grava com File.binwrite.
pdf_bytes = $nfe.service_invoices.download_pdf(company_id: $company_id, invoice_id: invoice.id)
path = "nfse-#{invoice.id}.pdf"
File.binwrite(path, pdf_bytes)
puts "PDF salvo em #{path} (#{pdf_bytes.bytesize} bytes)"
