# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      ImportDeclarationResource = Data.define(:acquirer_federal_tax_number, :additions, :code, :customs_clearance_name, :customs_clearance_state, :customs_clearanced_on, :exporter, :intermediation, :international_transport, :registered_on, :state_third) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            acquirer_federal_tax_number: payload["acquirerFederalTaxNumber"],
            additions: (payload["additions"] || []).map { |e| AdditionResource.from_api(e) },
            code: payload["code"],
            customs_clearance_name: payload["customsClearanceName"],
            customs_clearance_state: payload["customsClearanceState"],
            customs_clearanced_on: payload["customsClearancedOn"],
            exporter: payload["exporter"],
            intermediation: payload["intermediation"],
            international_transport: payload["internationalTransport"],
            registered_on: payload["registeredOn"],
            state_third: payload["stateThird"],
          )
        end
      end
    end
  end
end
