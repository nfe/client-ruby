# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      ServiceAmountDefinitions = Data.define(:final_charged_amount, :fine_amount, :initial_charged_amount, :interest_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            final_charged_amount: payload["finalChargedAmount"],
            fine_amount: payload["fineAmount"],
            initial_charged_amount: payload["initialChargedAmount"],
            interest_amount: payload["interestAmount"],
          )
        end
      end
    end
  end
end
