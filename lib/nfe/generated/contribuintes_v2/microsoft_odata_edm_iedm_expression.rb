# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      Microsoft_OData_Edm_IEdmExpression = Data.define(:expression_kind) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            expression_kind: payload["expressionKind"],
          )
        end
      end
    end
  end
end
