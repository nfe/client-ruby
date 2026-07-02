# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-cte-v2.yaml
# Hash: sha256:6424379a8ca8cdf8129f24ec19b84b260208fc049a7d1d9cb8c45763c07af1a9

module Nfe
  module Generated
    module ConsultaCteV2
      DFe_NetCore_Domain_Resources_MetadataResource = Data.define(:access_key, :company, :created_on, :description, :federal_tax_number_sender, :id, :issued_on, :name_sender, :nsu, :parent_access_key, :product_invoices, :total_invoice_amount, :type, :xml_url) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            access_key: payload["accessKey"],
            company: DFe_NetCore_Domain_Resources_CompanyResource.from_api(payload["company"]),
            created_on: payload["createdOn"],
            description: payload["description"],
            federal_tax_number_sender: payload["federalTaxNumberSender"],
            id: payload["id"],
            issued_on: payload["issuedOn"],
            name_sender: payload["nameSender"],
            nsu: payload["nsu"],
            parent_access_key: payload["parentAccessKey"],
            product_invoices: (payload["productInvoices"] || []).map { |e| DFe_NetCore_Domain_Resources_ProductInvoiceResource.from_api(e) },
            total_invoice_amount: payload["totalInvoiceAmount"],
            type: payload["type"],
            xml_url: payload["xmlUrl"],
          )
        end
      end
    end
  end
end
