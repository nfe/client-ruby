# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      Total = Data.define(:ibs_cbs_totals, :icms, :is_totals, :issqn, :total_invoice_amount, :withheld_taxes) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            ibs_cbs_totals: IBSCBSTotalsResource.from_api(payload["ibsCbsTotals"]),
            icms: ICMSTotal.from_api(payload["icms"]),
            is_totals: ISTotalsResource.from_api(payload["isTotals"]),
            issqn: ISSQNTotal.from_api(payload["issqn"]),
            total_invoice_amount: payload["totalInvoiceAmount"],
            withheld_taxes: TotalsWithholdings.from_api(payload["withheldTaxes"]),
          )
        end
      end
    end
  end
end
