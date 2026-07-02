# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
