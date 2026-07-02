# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      DeliveryInformationResource = Data.define(:account_id, :address, :email, :federal_tax_number, :id, :name, :state_tax_number, :type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            address: AddressResource.from_api(payload["address"]),
            email: payload["email"],
            federal_tax_number: payload["federalTaxNumber"],
            id: payload["id"],
            name: payload["name"],
            state_tax_number: payload["stateTaxNumber"],
            type: payload["type"],
          )
        end
      end
    end
  end
end
