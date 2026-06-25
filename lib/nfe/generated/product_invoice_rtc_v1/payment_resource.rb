# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      PaymentResource = Data.define(:pay_back, :payment_detail) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            pay_back: payload["payBack"],
            payment_detail: (payload["paymentDetail"] || []).map { |e| PaymentDetailResource.from_api(e) },
          )
        end
      end
    end
  end
end
