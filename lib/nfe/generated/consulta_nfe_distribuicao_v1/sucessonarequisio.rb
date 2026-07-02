# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-nfe-distribuicao-v1.yaml
# Hash: sha256:c28db6c6fed93a58342537de8131850f266d0cdff71873a3bab126b3309e3ea7

module Nfe
  module Generated
    module ConsultaNfeDistribuicaoV1
      Sucessonarequisio = Data.define(:access_key, :buyer, :company, :created_on, :description, :federal_tax_number_sender, :id, :issued_on, :issuer, :links, :name_sender, :nfe_number, :nfe_serial_number, :nsu, :nsu_parent, :operation_type, :parent_access_key, :total_invoice_amount, :transportation, :type, :xml_url) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            access_key: payload["accessKey"],
            buyer: Buyer.from_api(payload["buyer"]),
            company: Company.from_api(payload["company"]),
            created_on: payload["createdOn"],
            description: payload["description"],
            federal_tax_number_sender: payload["federalTaxNumberSender"],
            id: payload["id"],
            issued_on: payload["issuedOn"],
            issuer: Issuer.from_api(payload["issuer"]),
            links: Links.from_api(payload["links"]),
            name_sender: payload["nameSender"],
            nfe_number: payload["nfeNumber"],
            nfe_serial_number: payload["nfeSerialNumber"],
            nsu: payload["nsu"],
            nsu_parent: payload["nsuParent"],
            operation_type: payload["operationType"],
            parent_access_key: payload["parentAccessKey"],
            total_invoice_amount: payload["totalInvoiceAmount"],
            transportation: Transportation.from_api(payload["transportation"]),
            type: payload["type"],
            xml_url: payload["xmlUrl"],
          )
        end
      end
    end
  end
end
