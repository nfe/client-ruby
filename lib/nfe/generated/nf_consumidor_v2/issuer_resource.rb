# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      IssuerResource = Data.define(:account_id, :address, :company_registry_number, :economic_activities, :email, :federal_tax_number, :id, :legal_nature, :municipal_tax_number, :name, :openning_date, :regional_sttax_number, :regional_tax_number, :special_tax_regime, :st_state_tax_number, :tax_regime, :trade_name, :type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            address: AddressResource.from_api(payload["address"]),
            company_registry_number: payload["companyRegistryNumber"],
            economic_activities: (payload["economicActivities"] || []).map { |e| EconomicActivityResource.from_api(e) },
            email: payload["email"],
            federal_tax_number: payload["federalTaxNumber"],
            id: payload["id"],
            legal_nature: payload["legalNature"],
            municipal_tax_number: payload["municipalTaxNumber"],
            name: payload["name"],
            openning_date: payload["openningDate"],
            regional_sttax_number: payload["regionalSTTaxNumber"],
            regional_tax_number: payload["regionalTaxNumber"],
            special_tax_regime: payload["specialTaxRegime"],
            st_state_tax_number: payload["stStateTaxNumber"],
            tax_regime: payload["taxRegime"],
            trade_name: payload["tradeName"],
            type: payload["type"],
          )
        end
      end
    end
  end
end
