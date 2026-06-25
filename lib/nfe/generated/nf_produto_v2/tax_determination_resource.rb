# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
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
