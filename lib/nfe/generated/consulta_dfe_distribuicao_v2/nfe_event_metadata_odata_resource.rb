# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-dfe-distribuicao-v2.yaml
# Hash: sha256:f607124386b9d5210012cd4ac84ed7a0e359939e4176cebe4103b5a525321bdd

module Nfe
  module Generated
    module ConsultaDfeDistribuicaoV2
      NFeEventMetadataODataResource = Data.define(:access_key, :company, :created_on, :description, :id, :nsu, :receipt_on, :type, :xml_url) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            access_key: payload["accessKey"],
            company: InboundCompanyResource.from_api(payload["company"]),
            created_on: payload["createdOn"],
            description: payload["description"],
            id: payload["id"],
            nsu: payload["nsu"],
            receipt_on: payload["receiptOn"],
            type: payload["type"],
            xml_url: payload["xmlUrl"],
          )
        end
      end
    end
  end
end
