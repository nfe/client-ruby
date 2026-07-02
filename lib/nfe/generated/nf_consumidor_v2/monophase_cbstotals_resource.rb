# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      MonophaseCBSTotalsResource = Data.define(:amount, :previously_withheld_amount, :withheld_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            previously_withheld_amount: payload["previouslyWithheldAmount"],
            withheld_amount: payload["withheldAmount"],
          )
        end
      end
    end
  end
end
