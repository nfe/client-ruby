# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
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
