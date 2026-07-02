# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-cte-v2.yaml
# Hash: sha256:6424379a8ca8cdf8129f24ec19b84b260208fc049a7d1d9cb8c45763c07af1a9

module Nfe
  module Generated
    module ConsultaCteV2
      DFe_NetCore_Domain_Resources_TransportationInvoiceInboundResource = Data.define(:company_id, :created_on, :modified_on, :start_from_date, :start_from_nsu, :status) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            company_id: payload["companyId"],
            created_on: payload["createdOn"],
            modified_on: payload["modifiedOn"],
            start_from_date: payload["startFromDate"],
            start_from_nsu: payload["startFromNsu"],
            status: payload["status"],
          )
        end
      end
    end
  end
end
