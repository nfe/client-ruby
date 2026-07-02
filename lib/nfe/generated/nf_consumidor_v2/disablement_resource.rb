# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
