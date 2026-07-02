# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      IbsCbs = Data.define(:basis, :cbs, :class_code, :credit_transfer, :destination_indicator, :government_purchase, :ibs, :ibscbs_deduction_reduction_amount, :is_donation, :leased_movable_assets, :operation_indicator, :operation_type, :personal_use, :presumed_credits, :purpose, :regular_taxation, :reimbursed_resupplied_amount, :related_docs, :situation_code, :third_party_reimbursements) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            basis: payload["basis"],
            cbs: payload["cbs"],
            class_code: payload["classCode"],
            credit_transfer: payload["creditTransfer"],
            destination_indicator: payload["destinationIndicator"],
            government_purchase: payload["governmentPurchase"],
            ibs: payload["ibs"],
            ibscbs_deduction_reduction_amount: payload["ibscbsDeductionReductionAmount"],
            is_donation: payload["isDonation"],
            leased_movable_assets: payload["leasedMovableAssets"],
            operation_indicator: payload["operationIndicator"],
            operation_type: payload["operationType"],
            personal_use: payload["personalUse"],
            presumed_credits: payload["presumedCredits"],
            purpose: payload["purpose"],
            regular_taxation: payload["regularTaxation"],
            reimbursed_resupplied_amount: payload["reimbursedResuppliedAmount"],
            related_docs: payload["relatedDocs"],
            situation_code: payload["situationCode"],
            third_party_reimbursements: payload["thirdPartyReimbursements"],
          )
        end
      end
    end
  end
end
