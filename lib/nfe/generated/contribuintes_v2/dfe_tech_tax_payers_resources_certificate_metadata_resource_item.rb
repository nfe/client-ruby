# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_CertificateMetadataResourceItem = Data.define(:modified_on, :status, :subject, :tax_id, :tax_payer_id, :thumbprint, :valid_until) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            modified_on: payload["modifiedOn"],
            status: payload["status"],
            subject: payload["subject"],
            tax_id: payload["taxId"],
            tax_payer_id: payload["taxPayerId"],
            thumbprint: payload["thumbprint"],
            valid_until: payload["validUntil"],
          )
        end
      end
    end
  end
end
