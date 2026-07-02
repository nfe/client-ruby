# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      Deduction = Data.define(:amount, :documents, :rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            documents: (payload["documents"] || []).map { |e| DeductionDocument.from_api(e) },
            rate: payload["rate"],
          )
        end
      end
    end
  end
end
