# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      TaxDeterminationResource = Data.define(:acquisition_purpose, :buyer_tax_profile, :issuer_tax_profile, :operation_code, :origin) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            acquisition_purpose: payload["acquisitionPurpose"],
            buyer_tax_profile: payload["buyerTaxProfile"],
            issuer_tax_profile: payload["issuerTaxProfile"],
            operation_code: payload["operationCode"],
            origin: payload["origin"],
          )
        end
      end
    end
  end
end
