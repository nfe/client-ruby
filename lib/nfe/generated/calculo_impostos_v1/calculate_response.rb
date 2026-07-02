# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      CalculateResponse = Data.define(:items) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            items: (payload["items"] || []).map { |e| CalculateItemResponse.from_api(e) },
          )
        end
      end
    end
  end
end
