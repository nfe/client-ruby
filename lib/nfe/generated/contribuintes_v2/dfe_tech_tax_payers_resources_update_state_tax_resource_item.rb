# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_UpdateStateTaxResourceItem = Data.define(:code, :environment_type, :number, :processing_details, :security_credential, :serie, :special_tax_regime, :tax_number, :type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            code: payload["code"],
            environment_type: payload["environmentType"],
            number: payload["number"],
            processing_details: DFeTech_TaxPayers_Resources_CreateStateTaxProcessingDetailsResource.from_api(payload["processingDetails"]),
            security_credential: DFeTech_TaxPayers_Domain_Entities_SecurityCredential.from_api(payload["securityCredential"]),
            serie: payload["serie"],
            special_tax_regime: payload["specialTaxRegime"],
            tax_number: payload["taxNumber"],
            type: payload["type"],
          )
        end
      end
    end
  end
end
