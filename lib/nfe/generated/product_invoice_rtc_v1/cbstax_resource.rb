# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      CBSTaxResource = Data.define(:amount, :deferment, :rate, :reduction, :returned_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            deferment: DefermentTaxResource.from_api(payload["deferment"]),
            rate: payload["rate"],
            reduction: ReductionTaxResource.from_api(payload["reduction"]),
            returned_amount: ReturnedTaxResource.from_api(payload["returnedAmount"]),
          )
        end
      end
    end
  end
end
