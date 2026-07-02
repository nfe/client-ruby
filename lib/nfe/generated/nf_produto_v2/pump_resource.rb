# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
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
