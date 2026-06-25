# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
