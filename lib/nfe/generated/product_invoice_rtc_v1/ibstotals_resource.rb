# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      IBSTotalsResource = Data.define(:municipal, :presumed_credit_amount, :presumed_credit_conditional_amount, :state, :total_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            municipal: IBSMunicipalTotalsResource.from_api(payload["municipal"]),
            presumed_credit_amount: payload["presumedCreditAmount"],
            presumed_credit_conditional_amount: payload["presumedCreditConditionalAmount"],
            state: IBSStateTotalsResource.from_api(payload["state"]),
            total_amount: payload["totalAmount"],
          )
        end
      end
    end
  end
end
