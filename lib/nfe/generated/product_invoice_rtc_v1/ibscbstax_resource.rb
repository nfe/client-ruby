# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      IBSCBSTaxResource = Data.define(:basis, :calculation_mode, :cbs, :class_code, :credit_reversal, :credit_transfer, :donation_indicator, :government_purchase, :ibs_total_amount, :monophase, :municipal, :operational_presumed_credit, :regular_taxation, :situation_code, :state, :zfm_presumed_credit) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            basis: payload["basis"],
            calculation_mode: payload["calculationMode"],
            cbs: CBSTaxResource.from_api(payload["cbs"]),
            class_code: payload["classCode"],
            credit_reversal: CreditReversalResource.from_api(payload["creditReversal"]),
            credit_transfer: CreditTransferTaxResource.from_api(payload["creditTransfer"]),
            donation_indicator: payload["donationIndicator"],
            government_purchase: GovernmentPurchaseTaxResource.from_api(payload["governmentPurchase"]),
            ibs_total_amount: payload["ibsTotalAmount"],
            monophase: MonophaseIBSCBSTaxResource.from_api(payload["monophase"]),
            municipal: IBSMunicipalTaxResource.from_api(payload["municipal"]),
            operational_presumed_credit: OperationalPresumedCreditResource.from_api(payload["operationalPresumedCredit"]),
            regular_taxation: RegularTaxationResource.from_api(payload["regularTaxation"]),
            situation_code: payload["situationCode"],
            state: IBSStateTaxResource.from_api(payload["state"]),
            zfm_presumed_credit: ZfmPresumedCreditResource.from_api(payload["zfmPresumedCredit"]),
          )
        end
      end
    end
  end
end
