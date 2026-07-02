# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      IBSCBSTotalsResource = Data.define(:basis, :cbs, :credit_reversal, :ibs, :monophase) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            basis: payload["basis"],
            cbs: CBSTotalsResource.from_api(payload["cbs"]),
            credit_reversal: CreditReversalTotalsResource.from_api(payload["creditReversal"]),
            ibs: IBSTotalsResource.from_api(payload["ibs"]),
            monophase: MonophaseTotalsResource.from_api(payload["monophase"]),
          )
        end
      end
    end
  end
end
