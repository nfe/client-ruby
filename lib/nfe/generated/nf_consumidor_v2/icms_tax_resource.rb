# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      IcmsTaxResource = Data.define(:amount, :amount_operation, :amount_streason, :base_deferred, :base_snretention_amount, :base_stretention_amount, :base_tax, :base_tax_fcpstamount, :base_tax_modality, :base_tax_operation_percentual, :base_tax_reduction, :base_tax_st, :base_tax_stmodality, :base_tax_streduction, :basis_benefit_code, :csosn, :cst, :deduction_indicator, :effective_amount, :effective_base_tax_amount, :effective_base_tax_reduction_rate, :effective_rate, :exempt_amount, :exempt_amount_st, :exempt_reason, :exempt_reason_st, :fcp_amount, :fcp_rate, :fcpst_amount, :fcpst_rate, :fcpst_ret_amount, :fcpst_ret_rate, :origin, :percentual, :percentual_deferment, :rate, :sn_credit_amount, :sn_credit_rate, :sn_retention_amount, :st_amount, :st_final_consumer_rate, :st_margin_added_amount, :st_margin_amount, :st_rate, :st_retention_amount, :substitute_amount, :ufst) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            amount: payload["amount"],
            amount_operation: payload["amountOperation"],
            amount_streason: payload["amountSTReason"],
            base_deferred: payload["baseDeferred"],
            base_snretention_amount: payload["baseSNRetentionAmount"],
            base_stretention_amount: payload["baseSTRetentionAmount"],
            base_tax: payload["baseTax"],
            base_tax_fcpstamount: payload["baseTaxFCPSTAmount"],
            base_tax_modality: payload["baseTaxModality"],
            base_tax_operation_percentual: payload["baseTaxOperationPercentual"],
            base_tax_reduction: payload["baseTaxReduction"],
            base_tax_st: payload["baseTaxST"],
            base_tax_stmodality: payload["baseTaxSTModality"],
            base_tax_streduction: payload["baseTaxSTReduction"],
            basis_benefit_code: payload["basisBenefitCode"],
            csosn: payload["csosn"],
            cst: payload["cst"],
            deduction_indicator: payload["deductionIndicator"],
            effective_amount: payload["effectiveAmount"],
            effective_base_tax_amount: payload["effectiveBaseTaxAmount"],
            effective_base_tax_reduction_rate: payload["effectiveBaseTaxReductionRate"],
            effective_rate: payload["effectiveRate"],
            exempt_amount: payload["exemptAmount"],
            exempt_amount_st: payload["exemptAmountST"],
            exempt_reason: payload["exemptReason"],
            exempt_reason_st: payload["exemptReasonST"],
            fcp_amount: payload["fcpAmount"],
            fcp_rate: payload["fcpRate"],
            fcpst_amount: payload["fcpstAmount"],
            fcpst_rate: payload["fcpstRate"],
            fcpst_ret_amount: payload["fcpstRetAmount"],
            fcpst_ret_rate: payload["fcpstRetRate"],
            origin: payload["origin"],
            percentual: payload["percentual"],
            percentual_deferment: payload["percentualDeferment"],
            rate: payload["rate"],
            sn_credit_amount: payload["snCreditAmount"],
            sn_credit_rate: payload["snCreditRate"],
            sn_retention_amount: payload["snRetentionAmount"],
            st_amount: payload["stAmount"],
            st_final_consumer_rate: payload["stFinalConsumerRate"],
            st_margin_added_amount: payload["stMarginAddedAmount"],
            st_margin_amount: payload["stMarginAmount"],
            st_rate: payload["stRate"],
            st_retention_amount: payload["stRetentionAmount"],
            substitute_amount: payload["substituteAmount"],
            ufst: payload["ufst"],
          )
        end
      end
    end
  end
end
