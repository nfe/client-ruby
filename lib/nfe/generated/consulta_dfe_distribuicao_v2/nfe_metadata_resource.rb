# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-dfe-distribuicao-v2.yaml
# Hash: sha256:f607124386b9d5210012cd4ac84ed7a0e359939e4176cebe4103b5a525321bdd

module Nfe
  module Generated
    module ConsultaDfeDistribuicaoV2
      NFeMetadataResource = Data.define(:access_key, :buyer, :company, :created_on, :description, :federal_tax_number_sender, :issued_on, :issuer, :name_sender, :nfe_number, :nfe_serial_number, :nsu, :nsu_parent, :operation_type, :parent_access_key, :total_invoice_amount, :transportation, :type, :xml_url) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            access_key: payload["accessKey"],
            buyer: BuyerResource.from_api(payload["buyer"]),
            company: InboundCompanyResource.from_api(payload["company"]),
            created_on: payload["createdOn"],
            description: payload["description"],
            federal_tax_number_sender: payload["federalTaxNumberSender"],
            issued_on: payload["issuedOn"],
            issuer: IssuerResource.from_api(payload["issuer"]),
            name_sender: payload["nameSender"],
            nfe_number: payload["nfeNumber"],
            nfe_serial_number: payload["nfeSerialNumber"],
            nsu: payload["nsu"],
            nsu_parent: payload["nsuParent"],
            operation_type: payload["operationType"],
            parent_access_key: payload["parentAccessKey"],
            total_invoice_amount: payload["totalInvoiceAmount"],
            transportation: TransportationResource.from_api(payload["transportation"]),
            type: payload["type"],
            xml_url: payload["xmlUrl"],
          )
        end
      end
    end
  end
end
