# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-nfe-distribuicao-v1.yaml
# Hash: sha256:c28db6c6fed93a58342537de8131850f266d0cdff71873a3bab126b3309e3ea7

module Nfe
  module Generated
    module ConsultaNfeDistribuicaoV1
      AtivarbuscaautomticadedocumentoseEventosrelacionadosaNotaFiscalEletrnicaNF_eRequest = Data.define(:automatic_manifesting, :environment_sefaz, :start_from_date, :start_from_nsu, :webhook_version) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            automatic_manifesting: AutomaticManifesting.from_api(payload["automaticManifesting"]),
            environment_sefaz: payload["environmentSEFAZ"],
            start_from_date: payload["startFromDate"],
            start_from_nsu: payload["startFromNsu"],
            webhook_version: payload["webhookVersion"],
          )
        end
      end
    end
  end
end
