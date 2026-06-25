# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
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
