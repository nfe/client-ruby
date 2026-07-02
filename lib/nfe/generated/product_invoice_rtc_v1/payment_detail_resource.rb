# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      PaymentDetailResource = Data.define(:amount, :card, :federal_tax_number_pag, :method, :method_description, :payment_date, :payment_type, :state_pag) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            card: CardResource.from_api(payload["card"]),
            federal_tax_number_pag: payload["federalTaxNumberPag"],
            method: payload["method"],
            method_description: payload["methodDescription"],
            payment_date: payload["paymentDate"],
            payment_type: payload["paymentType"],
            state_pag: payload["statePag"],
          )
        end
      end
    end
  end
end
