# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      BillResource = Data.define(:discount_amount, :net_amount, :number, :original_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            discount_amount: payload["discountAmount"],
            net_amount: payload["netAmount"],
            number: payload["number"],
            original_amount: payload["originalAmount"],
          )
        end
      end
    end
  end
end
