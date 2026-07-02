# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_CompanyResourceItem = Data.define(:account_id, :address, :created_on, :federal_tax_number, :id, :modified_on, :municipal_tax_number, :municipal_taxes, :name, :state_taxes, :status, :tax_regime, :trade_name) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            address: DFeTech_TaxPayers_Resources_AddressResource.from_api(payload["address"]),
            created_on: payload["createdOn"],
            federal_tax_number: payload["federalTaxNumber"],
            id: payload["id"],
            modified_on: payload["modifiedOn"],
            municipal_tax_number: payload["municipalTaxNumber"],
            municipal_taxes: payload["municipalTaxes"],
            name: payload["name"],
            state_taxes: payload["stateTaxes"],
            status: payload["status"],
            tax_regime: payload["taxRegime"],
            trade_name: payload["tradeName"],
          )
        end
      end
    end
  end
end
