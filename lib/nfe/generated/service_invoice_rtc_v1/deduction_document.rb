# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      DeductionDocument = Data.define(:deductible_total, :deduction_type, :fiscal_document_number, :issue_date, :municipal_nfse, :nfe_key, :nfse_key, :non_fiscal_document_number, :other_deduction_description, :supplier, :used_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            deductible_total: payload["deductibleTotal"],
            deduction_type: payload["deductionType"],
            fiscal_document_number: payload["fiscalDocumentNumber"],
            issue_date: payload["issueDate"],
            municipal_nfse: payload["municipalNfse"],
            nfe_key: payload["nfeKey"],
            nfse_key: payload["nfseKey"],
            non_fiscal_document_number: payload["nonFiscalDocumentNumber"],
            other_deduction_description: payload["otherDeductionDescription"],
            supplier: PartyDefinition.from_api(payload["supplier"]),
            used_amount: payload["usedAmount"],
          )
        end
      end
    end
  end
end
