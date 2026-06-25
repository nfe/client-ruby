# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      GovernmentPurchaseTaxResource = Data.define(:cbs_amount, :cbs_rate, :municipal_amount, :municipal_rate, :state_amount, :state_rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cbs_amount: payload["cbsAmount"],
            cbs_rate: payload["cbsRate"],
            municipal_amount: payload["municipalAmount"],
            municipal_rate: payload["municipalRate"],
            state_amount: payload["stateAmount"],
            state_rate: payload["stateRate"],
          )
        end
      end
    end
  end
end
