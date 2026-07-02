# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-dfe-distribuicao-v2.yaml
# Hash: sha256:f607124386b9d5210012cd4ac84ed7a0e359939e4176cebe4103b5a525321bdd

module Nfe
  module Generated
    module ConsultaDfeDistribuicaoV2
      NFeMetadataODataResource = Data.define(:access_key, :company, :created_on, :federal_tax_number_sender, :issued_on, :name_sender, :nfe_number, :nfe_serial_number, :nsu, :operation_type, :total_invoice_amount, :type, :xml_url) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            access_key: payload["accessKey"],
            company: InboundCompanyResource.from_api(payload["company"]),
            created_on: payload["createdOn"],
            federal_tax_number_sender: payload["federalTaxNumberSender"],
            issued_on: payload["issuedOn"],
            name_sender: payload["nameSender"],
            nfe_number: payload["nfeNumber"],
            nfe_serial_number: payload["nfeSerialNumber"],
            nsu: payload["nsu"],
            operation_type: payload["operationType"],
            total_invoice_amount: payload["totalInvoiceAmount"],
            type: payload["type"],
            xml_url: payload["xmlUrl"],
          )
        end
      end
    end
  end
end
