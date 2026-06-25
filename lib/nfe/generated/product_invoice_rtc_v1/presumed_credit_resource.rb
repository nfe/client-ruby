# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      PresumedCreditResource = Data.define(:amount, :code, :rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            code: payload["code"],
            rate: payload["rate"],
          )
        end
      end
    end
  end
end
