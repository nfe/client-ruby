# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      TransportInformationResource = Data.define(:freight_modality, :reboque, :seal_number, :transp_rate, :transport_group, :transport_vehicle, :volume) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            freight_modality: payload["freightModality"],
            reboque: ReboqueResource.from_api(payload["reboque"]),
            seal_number: payload["sealNumber"],
            transp_rate: TransportRateResource.from_api(payload["transpRate"]),
            transport_group: TransportGroupResource.from_api(payload["transportGroup"]),
            transport_vehicle: TransportVehicleResource.from_api(payload["transportVehicle"]),
            volume: VolumeResource.from_api(payload["volume"]),
          )
        end
      end
    end
  end
end
