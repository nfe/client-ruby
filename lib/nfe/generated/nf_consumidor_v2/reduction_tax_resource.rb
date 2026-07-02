# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      ReductionTaxResource = Data.define(:effective_rate, :rate_reduction) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            effective_rate: payload["effectiveRate"],
            rate_reduction: payload["rateReduction"],
          )
        end
      end
    end
  end
end
