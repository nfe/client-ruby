# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_CompanyResourceV1 = Data.define(:address, :auth_issue_value, :certificate, :company_registry_number, :created_on, :email, :environment, :federal_tax_determination, :federal_tax_number, :fiscal_status, :id, :iss_rate, :last_rps_sent, :legal_nature, :login_name, :login_password, :modified_on, :municipal_tax_determination, :municipal_tax_number, :name, :openning_date, :regional_tax_number, :rps_number, :rps_serial_number, :special_tax_regime, :status, :tax_regime, :trade_name) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            address: DFeTech_TaxPayers_Domain_Entities_Address.from_api(payload["address"]),
            auth_issue_value: payload["authIssueValue"],
            certificate: DFeTech_TaxPayers_Resources_CompanyCertificateV1.from_api(payload["certificate"]),
            company_registry_number: payload["companyRegistryNumber"],
            created_on: payload["createdOn"],
            email: payload["email"],
            environment: payload["environment"],
            federal_tax_determination: payload["federalTaxDetermination"],
            federal_tax_number: payload["federalTaxNumber"],
            fiscal_status: payload["fiscalStatus"],
            id: payload["id"],
            iss_rate: payload["issRate"],
            last_rps_sent: payload["lastRpsSent"],
            legal_nature: payload["legalNature"],
            login_name: payload["loginName"],
            login_password: payload["loginPassword"],
            modified_on: payload["modifiedOn"],
            municipal_tax_determination: payload["municipalTaxDetermination"],
            municipal_tax_number: payload["municipalTaxNumber"],
            name: payload["name"],
            openning_date: payload["openningDate"],
            regional_tax_number: payload["regionalTaxNumber"],
            rps_number: payload["rpsNumber"],
            rps_serial_number: payload["rpsSerialNumber"],
            special_tax_regime: payload["specialTaxRegime"],
            status: payload["status"],
            tax_regime: payload["taxRegime"],
            trade_name: payload["tradeName"],
          )
        end
      end
    end
  end
end
