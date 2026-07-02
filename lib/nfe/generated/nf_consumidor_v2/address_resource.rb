# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      AddressResource = Data.define(:additional_information, :city, :country, :district, :number, :phone, :postal_code, :state, :street) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            additional_information: payload["additionalInformation"],
            city: CityResource.from_api(payload["city"]),
            country: payload["country"],
            district: payload["district"],
            number: payload["number"],
            phone: payload["phone"],
            postal_code: payload["postalCode"],
            state: payload["state"],
            street: payload["street"],
          )
        end
      end
    end
  end
end
