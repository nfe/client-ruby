# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      IBSTotalsResource = Data.define(:municipal, :presumed_credit_amount, :presumed_credit_conditional_amount, :state, :total_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            municipal: IBSMunicipalTotalsResource.from_api(payload["municipal"]),
            presumed_credit_amount: payload["presumedCreditAmount"],
            presumed_credit_conditional_amount: payload["presumedCreditConditionalAmount"],
            state: IBSStateTotalsResource.from_api(payload["state"]),
            total_amount: payload["totalAmount"],
          )
        end
      end
    end
  end
end
