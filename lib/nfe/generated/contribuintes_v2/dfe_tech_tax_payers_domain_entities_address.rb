# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Domain_Entities_Address = Data.define(:additional_information, :city, :country, :district, :number, :postal_code, :state, :street, :street_prefix) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            additional_information: payload["additionalInformation"],
            city: DFeTech_TaxPayers_Domain_Entities_CityBase.from_api(payload["city"]),
            country: payload["country"],
            district: payload["district"],
            number: payload["number"],
            postal_code: payload["postalCode"],
            state: payload["state"],
            street: payload["street"],
            street_prefix: payload["streetPrefix"],
          )
        end
      end
    end
  end
end
