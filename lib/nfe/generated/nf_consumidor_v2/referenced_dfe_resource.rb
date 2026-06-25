# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      ReferencedDFeResource = Data.define(:access_key, :item_number) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            access_key: payload["accessKey"],
            item_number: payload["itemNumber"],
          )
        end
      end
    end
  end
end
