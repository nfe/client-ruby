# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-register-pt-br-v1.yaml
# Hash: sha256:beba0a3fb4dc1bc157a5a4a28e55768cea0e7390b491bdd4bedee2ee2297ca64

module Nfe
  module Generated
    module ProductRegisterPtBrV1
      CustomTaxScenario = Data.define(:operation_code, :inter_state, :intra_state, :issuer, :recipient) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            operation_code: payload["OperationCode"],
            inter_state: InterStateTaxGroup.from_api(payload["interState"]),
            intra_state: IntraStateTaxGroup.from_api(payload["intraState"]),
            issuer: payload["issuer"],
            recipient: payload["recipient"],
          )
        end
      end
    end
  end
end
