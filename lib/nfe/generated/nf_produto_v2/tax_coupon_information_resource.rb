# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      TaxCouponInformationResource = Data.define(:model_document_fiscal, :order_count_operation, :order_ecf) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            model_document_fiscal: payload["modelDocumentFiscal"],
            order_count_operation: payload["orderCountOperation"],
            order_ecf: payload["orderECF"],
          )
        end
      end
    end
  end
end
