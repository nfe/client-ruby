# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
