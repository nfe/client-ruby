# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      VolumeResource = Data.define(:brand, :gross_weight, :net_weight, :species, :volume_numeration, :volume_quantity) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            brand: payload["brand"],
            gross_weight: payload["grossWeight"],
            net_weight: payload["netWeight"],
            species: payload["species"],
            volume_numeration: payload["volumeNumeration"],
            volume_quantity: payload["volumeQuantity"],
          )
        end
      end
    end
  end
end
