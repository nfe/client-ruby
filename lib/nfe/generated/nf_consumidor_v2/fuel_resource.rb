# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
