# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      DisablementResource = Data.define(:begin_number, :environment, :last_number, :reason, :serie, :state) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            begin_number: payload["beginNumber"],
            environment: payload["environment"],
            last_number: payload["lastNumber"],
            reason: payload["reason"],
            serie: payload["serie"],
            state: payload["state"],
          )
        end
      end
    end
  end
end
