# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
