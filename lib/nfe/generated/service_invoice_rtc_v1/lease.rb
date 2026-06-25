# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      Lease = Data.define(:category, :object_type, :poles_count, :total_length) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            category: payload["category"],
            object_type: payload["objectType"],
            poles_count: payload["polesCount"],
            total_length: payload["totalLength"],
          )
        end
      end
    end
  end
end
