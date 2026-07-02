# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      DocumentInvoiceReferenceResource = Data.define(:federal_tax_number, :model, :number, :series, :state, :year_month) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            federal_tax_number: payload["federalTaxNumber"],
            model: payload["model"],
            number: payload["number"],
            series: payload["series"],
            state: payload["state"],
            year_month: payload["yearMonth"],
          )
        end
      end
    end
  end
end
