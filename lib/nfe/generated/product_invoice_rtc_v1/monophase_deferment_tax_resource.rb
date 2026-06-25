# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      MonophaseDefermentTaxResource = Data.define(:cbs_amount, :cbs_rate, :ibs_amount, :ibs_rate) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cbs_amount: payload["cbsAmount"],
            cbs_rate: payload["cbsRate"],
            ibs_amount: payload["ibsAmount"],
            ibs_rate: payload["ibsRate"],
          )
        end
      end
    end
  end
end
