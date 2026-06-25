# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
