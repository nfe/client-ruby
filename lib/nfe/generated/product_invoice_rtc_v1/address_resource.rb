# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
