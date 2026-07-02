# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      IPITaxResource = Data.define(:amount, :base, :classification, :classification_code, :cst, :producer_cnpj, :rate, :stamp_code, :stamp_quantity, :unit_amount, :unit_quantity) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            base: payload["base"],
            classification: payload["classification"],
            classification_code: payload["classificationCode"],
            cst: payload["cst"],
            producer_cnpj: payload["producerCNPJ"],
            rate: payload["rate"],
            stamp_code: payload["stampCode"],
            stamp_quantity: payload["stampQuantity"],
            unit_amount: payload["unitAmount"],
            unit_quantity: payload["unitQuantity"],
          )
        end
      end
    end
  end
end
