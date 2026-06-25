# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      PartyDefinition = Data.define(:address, :caepf, :email, :federal_tax_number, :municipal_tax_number, :name, :no_tax_id_reason, :phone_number, :state_tax_number, :tax_regime, :type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            address: AddressDefinition.from_api(payload["address"]),
            caepf: payload["caepf"],
            email: payload["email"],
            federal_tax_number: payload["federalTaxNumber"],
            municipal_tax_number: payload["municipalTaxNumber"],
            name: payload["name"],
            no_tax_id_reason: payload["noTaxIdReason"],
            phone_number: payload["phoneNumber"],
            state_tax_number: payload["stateTaxNumber"],
            tax_regime: payload["taxRegime"],
            type: payload["type"],
          )
        end
      end
    end
  end
end
