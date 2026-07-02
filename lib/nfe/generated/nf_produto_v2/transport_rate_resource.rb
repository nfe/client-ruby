# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      TransportRateResource = Data.define(:bc_retention_amount, :cfop, :city_generator_fact_code, :icms_retention_amount, :icms_retention_rate, :service_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            bc_retention_amount: payload["bcRetentionAmount"],
            cfop: payload["cfop"],
            city_generator_fact_code: payload["cityGeneratorFactCode"],
            icms_retention_amount: payload["icmsRetentionAmount"],
            icms_retention_rate: payload["icmsRetentionRate"],
            service_amount: payload["serviceAmount"],
          )
        end
      end
    end
  end
end
