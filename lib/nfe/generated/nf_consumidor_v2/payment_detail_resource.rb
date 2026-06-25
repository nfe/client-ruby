# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
