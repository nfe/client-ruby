# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      IPITaxResource = Data.define(:amount, :base, :classification, :classification_code, :cst, :producer_cnpj, :rate, :stamp_code, :stamp_quantity, :unit_amount, :unit_quantity) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            base: payload["base"],
            classification: payload["classification"],
            classification_code: payload["classificationCode"],
            cst: payload["cst"],
            producer_cnpj: payload["producerCNPJ"],
            rate: payload["rate"],
            stamp_code: payload["stampCode"],
            stamp_quantity: payload["stampQuantity"],
            unit_amount: payload["unitAmount"],
            unit_quantity: payload["unitQuantity"],
          )
        end
      end
    end
  end
end
