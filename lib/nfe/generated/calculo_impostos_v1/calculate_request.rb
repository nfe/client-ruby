# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      CalculateRequest = Data.define(:collection_id, :is_product_registration, :issuer, :items, :operation_type, :recipient) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            collection_id: payload["collectionId"],
            is_product_registration: payload["isProductRegistration"],
            issuer: CalculateRequestIssuer.from_api(payload["issuer"]),
            items: (payload["items"] || []).map { |e| CalculateItemRequest.from_api(e) },
            operation_type: payload["operationType"],
            recipient: CalculateRequestRecipient.from_api(payload["recipient"]),
          )
        end
      end
    end
  end
end
