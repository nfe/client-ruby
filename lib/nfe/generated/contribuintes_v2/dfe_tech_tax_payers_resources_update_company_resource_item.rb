# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_UpdateCompanyResourceItem = Data.define(:account_id, :address, :federal_tax_number, :id, :municipal_tax_number, :name, :tax_regime, :trade_name) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            address: DFeTech_TaxPayers_Resources_AddressResource.from_api(payload["address"]),
            federal_tax_number: payload["federalTaxNumber"],
            id: payload["id"],
            municipal_tax_number: payload["municipalTaxNumber"],
            name: payload["name"],
            tax_regime: payload["taxRegime"],
            trade_name: payload["tradeName"],
          )
        end
      end
    end
  end
end
