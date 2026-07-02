# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
