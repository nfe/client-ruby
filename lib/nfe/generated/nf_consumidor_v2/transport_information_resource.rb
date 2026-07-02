# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
