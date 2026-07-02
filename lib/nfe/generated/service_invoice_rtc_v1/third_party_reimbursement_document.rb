# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      ThirdPartyReimbursementDocument = Data.define(:accrual_on, :amount, :cte_key, :issue_date, :nfe_key, :nfse_key, :other_doc, :other_fiscal_doc, :other_national_dfe, :reimbursement_type, :reimbursement_type_text, :supplier) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            accrual_on: payload["accrualOn"],
            amount: payload["amount"],
            cte_key: payload["cteKey"],
            issue_date: payload["issueDate"],
            nfe_key: payload["nfeKey"],
            nfse_key: payload["nfseKey"],
            other_doc: payload["otherDoc"],
            other_fiscal_doc: payload["otherFiscalDoc"],
            other_national_dfe: payload["otherNationalDfe"],
            reimbursement_type: payload["reimbursementType"],
            reimbursement_type_text: payload["reimbursementTypeText"],
            supplier: PartyDefinition.from_api(payload["supplier"]),
          )
        end
      end
    end
  end
end
