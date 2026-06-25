# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      PumpResource = Data.define(:beginning_amount, :end_amount, :number, :percentage_bio, :spout_number, :tank_number) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            beginning_amount: payload["beginningAmount"],
            end_amount: payload["endAmount"],
            number: payload["number"],
            percentage_bio: payload["percentageBio"],
            spout_number: payload["spoutNumber"],
            tank_number: payload["tankNumber"],
          )
        end
      end
    end
  end
end
