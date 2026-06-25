# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_StateTaxResourceItem = Data.define(:account_id, :code, :company_id, :created_on, :environment_type, :id, :modified_on, :number, :processing_details, :security_credential, :serie, :series, :special_tax_regime, :status, :tax_number, :type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            code: payload["code"],
            company_id: payload["companyId"],
            created_on: payload["createdOn"],
            environment_type: payload["environmentType"],
            id: payload["id"],
            modified_on: payload["modifiedOn"],
            number: payload["number"],
            processing_details: DFeTech_TaxPayers_Resources_CreateStateTaxProcessingDetailsResource.from_api(payload["processingDetails"]),
            security_credential: DFeTech_TaxPayers_Domain_Entities_SecurityCredential.from_api(payload["securityCredential"]),
            serie: payload["serie"],
            series: payload["series"],
            special_tax_regime: payload["specialTaxRegime"],
            status: payload["status"],
            tax_number: payload["taxNumber"],
            type: payload["type"],
          )
        end
      end
    end
  end
end
