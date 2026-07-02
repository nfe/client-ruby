# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-dfe-distribuicao-v2.yaml
# Hash: sha256:f607124386b9d5210012cd4ac84ed7a0e359939e4176cebe4103b5a525321bdd

module Nfe
  module Generated
    module ConsultaDfeDistribuicaoV2
      EnableInboundProductInvoiceResource = Data.define(:automatic_manifesting, :environment_sefaz, :start_from_date, :start_from_nsu) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            automatic_manifesting: payload["automaticManifesting"],
            environment_sefaz: payload["environmentSEFAZ"],
            start_from_date: payload["startFromDate"],
            start_from_nsu: payload["startFromNsu"],
          )
        end
      end
    end
  end
end
