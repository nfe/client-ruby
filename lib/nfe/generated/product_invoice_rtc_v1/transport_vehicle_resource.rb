# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      TransportVehicleResource = Data.define(:plate, :rntc, :state) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            plate: payload["plate"],
            rntc: payload["rntc"],
            state: payload["state"],
          )
        end
      end
    end
  end
end
