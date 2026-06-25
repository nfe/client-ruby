# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      FuelResource = Data.define(:amount_temp, :cide, :code_anp, :codif, :description_anp, :fuel_origin, :percentage_glp, :percentage_gni, :percentage_ng, :percentage_ngn, :pump, :starting_amount, :state_buyer) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount_temp: payload["amountTemp"],
            cide: CIDEResource.from_api(payload["cide"]),
            code_anp: payload["codeANP"],
            codif: payload["codif"],
            description_anp: payload["descriptionANP"],
            fuel_origin: FuelOriginResource.from_api(payload["fuelOrigin"]),
            percentage_glp: payload["percentageGLP"],
            percentage_gni: payload["percentageGNi"],
            percentage_ng: payload["percentageNG"],
            percentage_ngn: payload["percentageNGn"],
            pump: PumpResource.from_api(payload["pump"]),
            starting_amount: payload["startingAmount"],
            state_buyer: payload["stateBuyer"],
          )
        end
      end
    end
  end
end
