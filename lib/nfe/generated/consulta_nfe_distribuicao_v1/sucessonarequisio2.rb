# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-nfe-distribuicao-v1.yaml
# Hash: sha256:c28db6c6fed93a58342537de8131850f266d0cdff71873a3bab126b3309e3ea7

module Nfe
  module Generated
    module ConsultaNfeDistribuicaoV1
      Sucessonarequisio2 = Data.define(:automatic_manifesting, :company_id, :created_on, :environment_sefaz, :modified_on, :start_from_date, :start_from_nsu, :status, :webhook_version) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            automatic_manifesting: AutomaticManifesting.from_api(payload["automaticManifesting"]),
            company_id: payload["companyId"],
            created_on: payload["createdOn"],
            environment_sefaz: payload["environmentSEFAZ"],
            modified_on: payload["modifiedOn"],
            start_from_date: payload["startFromDate"],
            start_from_nsu: payload["startFromNsu"],
            status: payload["status"],
            webhook_version: payload["webhookVersion"],
          )
        end
      end
    end
  end
end
