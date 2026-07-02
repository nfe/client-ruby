# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
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
