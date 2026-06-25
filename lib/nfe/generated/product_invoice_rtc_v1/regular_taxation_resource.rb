# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      RegularTaxationResource = Data.define(:amount, :cbs_amount, :cbs_effective_rate, :class_code, :municipal_amount, :municipal_effective_rate, :situation_code, :state_effective_rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            cbs_amount: payload["cbsAmount"],
            cbs_effective_rate: payload["cbsEffectiveRate"],
            class_code: payload["classCode"],
            municipal_amount: payload["municipalAmount"],
            municipal_effective_rate: payload["municipalEffectiveRate"],
            situation_code: payload["situationCode"],
            state_effective_rate: payload["stateEffectiveRate"],
          )
        end
      end
    end
  end
end
