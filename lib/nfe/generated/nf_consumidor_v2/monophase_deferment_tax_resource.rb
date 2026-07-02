# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      MonophaseDefermentTaxResource = Data.define(:cbs_amount, :cbs_rate, :ibs_amount, :ibs_rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cbs_amount: payload["cbsAmount"],
            cbs_rate: payload["cbsRate"],
            ibs_amount: payload["ibsAmount"],
            ibs_rate: payload["ibsRate"],
          )
        end
      end
    end
  end
end
