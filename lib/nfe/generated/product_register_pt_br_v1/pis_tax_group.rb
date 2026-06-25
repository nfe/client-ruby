# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-register-pt-br-v1.yaml
# Hash: sha256:beba0a3fb4dc1bc157a5a4a28e55768cea0e7390b491bdd4bedee2ee2297ca64

module Nfe
  module Generated
    module ProductRegisterPtBrV1
      PisTaxGroup = Data.define(:cst, :p_pis) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cst: payload["cst"],
            p_pis: payload["pPIS"],
          )
        end
      end
    end
  end
end
