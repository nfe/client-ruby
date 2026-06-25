# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      TotalResource = Data.define(:ibs_cbs_totals, :icms, :is_totals, :issqn, :total_invoice_amount, :withheld_taxes) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            ibs_cbs_totals: IBSCBSTotalsResource.from_api(payload["ibsCbsTotals"]),
            icms: ICMSTotalResource.from_api(payload["icms"]),
            is_totals: ISTotalsResource.from_api(payload["isTotals"]),
            issqn: ISSQNTotalResource.from_api(payload["issqn"]),
            total_invoice_amount: payload["totalInvoiceAmount"],
            withheld_taxes: TotalsWithholdings.from_api(payload["withheldTaxes"]),
          )
        end
      end
    end
  end
end
