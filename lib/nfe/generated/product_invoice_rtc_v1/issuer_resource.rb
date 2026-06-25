# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
