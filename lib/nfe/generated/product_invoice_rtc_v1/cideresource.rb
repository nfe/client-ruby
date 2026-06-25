# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      CIDEResource = Data.define(:bc, :cide_amount, :rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            bc: payload["bc"],
            cide_amount: payload["cideAmount"],
            rate: payload["rate"],
          )
        end
      end
    end
  end
end
