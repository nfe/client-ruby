# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      IITaxResource = Data.define(:amount, :base_tax, :customs_expenditure_amount, :iof_amount, :v_enq_camb) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            base_tax: payload["baseTax"],
            customs_expenditure_amount: payload["customsExpenditureAmount"],
            iof_amount: payload["iofAmount"],
            v_enq_camb: payload["vEnqCamb"],
          )
        end
      end
    end
  end
end
