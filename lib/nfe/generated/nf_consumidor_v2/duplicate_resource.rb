# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      DuplicateResource = Data.define(:amount, :expiration_on, :number) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            expiration_on: payload["expirationOn"],
            number: payload["number"],
          )
        end
      end
    end
  end
end
