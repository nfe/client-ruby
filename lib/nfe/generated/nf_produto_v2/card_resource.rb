# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      CardResource = Data.define(:authorization, :federal_tax_number, :federal_tax_number_recipient, :flag, :id_payment_terminal, :integration_payment_type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            authorization: payload["authorization"],
            federal_tax_number: payload["federalTaxNumber"],
            federal_tax_number_recipient: payload["federalTaxNumberRecipient"],
            flag: payload["flag"],
            id_payment_terminal: payload["idPaymentTerminal"],
            integration_payment_type: payload["integrationPaymentType"],
          )
        end
      end
    end
  end
end
