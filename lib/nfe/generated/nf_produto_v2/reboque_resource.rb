# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      ReboqueResource = Data.define(:ferry, :plate, :rntc, :uf, :wagon) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            ferry: payload["ferry"],
            plate: payload["plate"],
            rntc: payload["rntc"],
            uf: payload["uf"],
            wagon: payload["wagon"],
          )
        end
      end
    end
  end
end
