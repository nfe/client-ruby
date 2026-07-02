# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-cte-v2.yaml
# Hash: sha256:6424379a8ca8cdf8129f24ec19b84b260208fc049a7d1d9cb8c45763c07af1a9

module Nfe
  module Generated
    module ConsultaCteV2
      DFe_NetCore_Domain_Resources_ProductInvoiceResource = Data.define(:access_key) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            access_key: payload["accessKey"],
          )
        end
      end
    end
  end
end
