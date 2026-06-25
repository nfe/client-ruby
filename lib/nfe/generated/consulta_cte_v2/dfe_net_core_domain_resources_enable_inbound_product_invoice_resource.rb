# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-cte-v2.yaml
# Hash: sha256:6424379a8ca8cdf8129f24ec19b84b260208fc049a7d1d9cb8c45763c07af1a9

module Nfe
  module Generated
    module ConsultaCteV2
      DFe_NetCore_Domain_Resources_EnableInboundProductInvoiceResource = Data.define(:automatic_manifesting, :start_from_date, :start_from_nsu) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            automatic_manifesting: DFe_NetCore_Domain_Resources_ManifestAutomaticRulesResource.from_api(payload["automaticManifesting"]),
            start_from_date: payload["startFromDate"],
            start_from_nsu: payload["startFromNsu"],
          )
        end
      end
    end
  end
end
