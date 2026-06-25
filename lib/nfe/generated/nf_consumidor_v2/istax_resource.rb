# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      ISTaxResource = Data.define(:amount, :basis, :classification_code, :quantity, :rate, :situation_code, :unit, :unit_rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            basis: payload["basis"],
            classification_code: payload["classificationCode"],
            quantity: payload["quantity"],
            rate: payload["rate"],
            situation_code: payload["situationCode"],
            unit: payload["unit"],
            unit_rate: payload["unitRate"],
          )
        end
      end
    end
  end
end
