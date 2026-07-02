# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      NFSeRequest = Data.define(:reference_substitution, :accrual_on, :activity_event, :additional_information, :additional_information_group, :approximate_tax, :approximate_totals, :benefit, :borrower, :city_service_code, :cnae_code, :cofins_amount, :cofins_amount_withheld, :cofins_rate, :construction, :csll_amount, :csll_amount_withheld, :csll_rate, :cst_pis_cofins, :deduction, :deductions_amount, :description, :discount_conditioned_amount, :discount_unconditioned_amount, :external_id, :federal_service_code, :foreign_trade, :ibs_cbs, :immunity_type, :inss_amount_withheld, :intermediary, :ipi_amount, :ipi_rate, :ir_amount_withheld, :is_early_installment_payment, :iss_amount_withheld, :iss_rate, :iss_tax_amount, :issued_on, :lease, :location, :nbs_code, :ncm_code, :others_amount_withheld, :paid_amount, :pis_amount, :pis_amount_withheld, :pis_cofins_base_tax, :pis_rate, :real_estate, :recipient, :retention_type, :rps_number, :rps_serial_number, :service_amount_details, :services_amount, :suspension, :taxation_type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            reference_substitution: ReferenceSubstitution.from_api(payload["ReferenceSubstitution"]),
            accrual_on: payload["accrualOn"],
            activity_event: ActivityEvent.from_api(payload["activityEvent"]),
            additional_information: payload["additionalInformation"],
            additional_information_group: payload["additionalInformationGroup"],
            approximate_tax: ApproximateTax.from_api(payload["approximateTax"]),
            approximate_totals: ApproximateTotals.from_api(payload["approximateTotals"]),
            benefit: Benefit.from_api(payload["benefit"]),
            borrower: PartyDefinition.from_api(payload["borrower"]),
            city_service_code: payload["cityServiceCode"],
            cnae_code: payload["cnaeCode"],
            cofins_amount: payload["cofinsAmount"],
            cofins_amount_withheld: payload["cofinsAmountWithheld"],
            cofins_rate: payload["cofinsRate"],
            construction: Construction.from_api(payload["construction"]),
            csll_amount: payload["csllAmount"],
            csll_amount_withheld: payload["csllAmountWithheld"],
            csll_rate: payload["csllRate"],
            cst_pis_cofins: payload["cstPisCofins"],
            deduction: Deduction.from_api(payload["deduction"]),
            deductions_amount: payload["deductionsAmount"],
            description: payload["description"],
            discount_conditioned_amount: payload["discountConditionedAmount"],
            discount_unconditioned_amount: payload["discountUnconditionedAmount"],
            external_id: payload["externalId"],
            federal_service_code: payload["federalServiceCode"],
            foreign_trade: ForeignTrade.from_api(payload["foreignTrade"]),
            ibs_cbs: IbsCbs.from_api(payload["ibsCbs"]),
            immunity_type: payload["immunityType"],
            inss_amount_withheld: payload["inssAmountWithheld"],
            intermediary: PartyDefinition.from_api(payload["intermediary"]),
            ipi_amount: payload["ipiAmount"],
            ipi_rate: payload["ipiRate"],
            ir_amount_withheld: payload["irAmountWithheld"],
            is_early_installment_payment: payload["isEarlyInstallmentPayment"],
            iss_amount_withheld: payload["issAmountWithheld"],
            iss_rate: payload["issRate"],
            iss_tax_amount: payload["issTaxAmount"],
            issued_on: payload["issuedOn"],
            lease: Lease.from_api(payload["lease"]),
            location: AddressDefinition.from_api(payload["location"]),
            nbs_code: payload["nbsCode"],
            ncm_code: payload["ncmCode"],
            others_amount_withheld: payload["othersAmountWithheld"],
            paid_amount: payload["paidAmount"],
            pis_amount: payload["pisAmount"],
            pis_amount_withheld: payload["pisAmountWithheld"],
            pis_cofins_base_tax: payload["pisCofinsBaseTax"],
            pis_rate: payload["pisRate"],
            real_estate: RealEstate.from_api(payload["realEstate"]),
            recipient: PartyDefinition.from_api(payload["recipient"]),
            retention_type: payload["retentionType"],
            rps_number: payload["rpsNumber"],
            rps_serial_number: payload["rpsSerialNumber"],
            service_amount_details: ServiceAmountDefinitions.from_api(payload["serviceAmountDetails"]),
            services_amount: payload["servicesAmount"],
            suspension: Suspension.from_api(payload["suspension"]),
            taxation_type: payload["taxationType"],
          )
        end
      end
    end
  end
end
