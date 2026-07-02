# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      ICMSTotalResource = Data.define(:base_tax, :cofins_amount, :discount_amount, :fcp_amount, :fcpst_amount, :fcpst_ret_amount, :fcpuf_destination_amount, :federal_taxes_amount, :freight_amount, :icms_amount, :icms_exempt_amount, :icmsuf_destination_amount, :icmsuf_sender_amount, :ii_amount, :insurance_amount, :invoice_amount, :ipi_amount, :ipi_devol_amount, :others_amount, :pis_amount, :product_amount, :q_bcmono, :q_bcmono_ret, :q_bcmono_reten, :st_amount, :st_calculation_basis_amount, :v_icmsmono, :v_icmsmono_ret, :v_icmsmono_reten) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            base_tax: payload["baseTax"],
            cofins_amount: payload["cofinsAmount"],
            discount_amount: payload["discountAmount"],
            fcp_amount: payload["fcpAmount"],
            fcpst_amount: payload["fcpstAmount"],
            fcpst_ret_amount: payload["fcpstRetAmount"],
            fcpuf_destination_amount: payload["fcpufDestinationAmount"],
            federal_taxes_amount: payload["federalTaxesAmount"],
            freight_amount: payload["freightAmount"],
            icms_amount: payload["icmsAmount"],
            icms_exempt_amount: payload["icmsExemptAmount"],
            icmsuf_destination_amount: payload["icmsufDestinationAmount"],
            icmsuf_sender_amount: payload["icmsufSenderAmount"],
            ii_amount: payload["iiAmount"],
            insurance_amount: payload["insuranceAmount"],
            invoice_amount: payload["invoiceAmount"],
            ipi_amount: payload["ipiAmount"],
            ipi_devol_amount: payload["ipiDevolAmount"],
            others_amount: payload["othersAmount"],
            pis_amount: payload["pisAmount"],
            product_amount: payload["productAmount"],
            q_bcmono: payload["qBCMono"],
            q_bcmono_ret: payload["qBCMonoRet"],
            q_bcmono_reten: payload["qBCMonoReten"],
            st_amount: payload["stAmount"],
            st_calculation_basis_amount: payload["stCalculationBasisAmount"],
            v_icmsmono: payload["vICMSMono"],
            v_icmsmono_ret: payload["vICMSMonoRet"],
            v_icmsmono_reten: payload["vICMSMonoReten"],
          )
        end
      end
    end
  end
end
