# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
