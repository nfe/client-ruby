# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      AddressDefinition = Data.define(:additional_information, :city, :country, :district, :number, :postal_code, :state, :street) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            additional_information: payload["additionalInformation"],
            city: payload["city"],
            country: payload["country"],
            district: payload["district"],
            number: payload["number"],
            postal_code: payload["postalCode"],
            state: payload["state"],
            street: payload["street"],
          )
        end
      end
    end
  end
end
