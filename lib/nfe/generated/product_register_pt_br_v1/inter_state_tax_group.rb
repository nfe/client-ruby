# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-register-pt-br-v1.yaml
# Hash: sha256:beba0a3fb4dc1bc157a5a4a28e55768cea0e7390b491bdd4bedee2ee2297ca64

module Nfe
  module Generated
    module ProductRegisterPtBrV1
      InterStateTaxGroup = Data.define(:cfop, :cofins, :icms, :pis) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cfop: payload["cfop"],
            cofins: CofinsTaxGroup.from_api(payload["cofins"]),
            icms: IcmsTaxGroup.from_api(payload["icms"]),
            pis: PisTaxGroup.from_api(payload["pis"]),
          )
        end
      end
    end
  end
end
