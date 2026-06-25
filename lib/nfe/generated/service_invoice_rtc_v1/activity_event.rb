# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      ActivityEvent = Data.define(:code, :address, :begin_on, :end_on, :name) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            code: payload["Code"],
            address: AddressDefinition.from_api(payload["address"]),
            begin_on: payload["beginOn"],
            end_on: payload["endOn"],
            name: payload["name"],
          )
        end
      end
    end
  end
end
