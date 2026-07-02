# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      CofinsTaxResource = Data.define(:amount, :base_tax, :base_tax_product_quantity, :cst, :product_rate, :rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            base_tax: payload["baseTax"],
            base_tax_product_quantity: payload["baseTaxProductQuantity"],
            cst: payload["cst"],
            product_rate: payload["productRate"],
            rate: payload["rate"],
          )
        end
      end
    end
  end
end
