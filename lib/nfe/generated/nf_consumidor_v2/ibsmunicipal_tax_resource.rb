# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      IBSMunicipalTaxResource = Data.define(:amount, :deferment, :rate, :reduction, :returned_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            deferment: DefermentTaxResource.from_api(payload["deferment"]),
            rate: payload["rate"],
            reduction: ReductionTaxResource.from_api(payload["reduction"]),
            returned_amount: ReturnedTaxResource.from_api(payload["returnedAmount"]),
          )
        end
      end
    end
  end
end
