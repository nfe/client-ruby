# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
