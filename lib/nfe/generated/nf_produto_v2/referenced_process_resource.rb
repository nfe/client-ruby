# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      ReferencedProcessResource = Data.define(:concession_act_type, :identifier_concessory, :identifier_origin) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            concession_act_type: payload["concessionActType"],
            identifier_concessory: payload["identifierConcessory"],
            identifier_origin: payload["identifierOrigin"],
          )
        end
      end
    end
  end
end
