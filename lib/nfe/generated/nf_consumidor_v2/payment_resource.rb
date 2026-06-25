# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
