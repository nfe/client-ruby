# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
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
