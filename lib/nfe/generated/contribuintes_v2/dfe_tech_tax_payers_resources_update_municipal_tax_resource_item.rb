# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_UpdateMunicipalTaxResourceItem = Data.define(:auth_issue_value, :city, :company_registry_number, :email, :environment, :federal_tax_determination, :iss_rate, :last_rps_sent, :legal_nature, :login_name, :login_password, :municipal_tax_determination, :regional_tax_number, :rps_number, :rps_serial_number, :special_tax_regime, :tax_number) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            auth_issue_value: payload["authIssueValue"],
            city: DFeTech_TaxPayers_Domain_Entities_CityExtended.from_api(payload["city"]),
            company_registry_number: payload["companyRegistryNumber"],
            email: payload["email"],
            environment: payload["environment"],
            federal_tax_determination: payload["federalTaxDetermination"],
            iss_rate: payload["issRate"],
            last_rps_sent: payload["lastRpsSent"],
            legal_nature: payload["legalNature"],
            login_name: payload["loginName"],
            login_password: payload["loginPassword"],
            municipal_tax_determination: payload["municipalTaxDetermination"],
            regional_tax_number: payload["regionalTaxNumber"],
            rps_number: payload["rpsNumber"],
            rps_serial_number: payload["rpsSerialNumber"],
            special_tax_regime: payload["specialTaxRegime"],
            tax_number: payload["taxNumber"],
          )
        end
      end
    end
  end
end
