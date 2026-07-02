# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
