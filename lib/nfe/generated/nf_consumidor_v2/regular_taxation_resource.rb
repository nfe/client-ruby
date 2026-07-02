# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      RegularTaxationResource = Data.define(:amount, :cbs_amount, :cbs_effective_rate, :class_code, :municipal_amount, :municipal_effective_rate, :situation_code, :state_effective_rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            cbs_amount: payload["cbsAmount"],
            cbs_effective_rate: payload["cbsEffectiveRate"],
            class_code: payload["classCode"],
            municipal_amount: payload["municipalAmount"],
            municipal_effective_rate: payload["municipalEffectiveRate"],
            situation_code: payload["situationCode"],
            state_effective_rate: payload["stateEffectiveRate"],
          )
        end
      end
    end
  end
end
