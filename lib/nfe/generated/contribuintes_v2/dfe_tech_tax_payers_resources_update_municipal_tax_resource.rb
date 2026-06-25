# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_UpdateMunicipalTaxResource = Data.define(:municipal_tax) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            municipal_tax: DFeTech_TaxPayers_Resources_UpdateMunicipalTaxResourceItem.from_api(payload["municipalTax"]),
          )
        end
      end
    end
  end
end
