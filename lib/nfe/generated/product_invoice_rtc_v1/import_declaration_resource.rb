# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      ImportDeclarationResource = Data.define(:acquirer_federal_tax_number, :additions, :afrmm_amount, :code, :customs_clearance_name, :customs_clearance_state, :customs_clearanced_on, :exporter, :intermediation, :international_transport, :registered_on, :state_third) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            acquirer_federal_tax_number: payload["acquirerFederalTaxNumber"],
            additions: (payload["additions"] || []).map { |e| AdditionResource.from_api(e) },
            afrmm_amount: payload["afrmmAmount"],
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
