# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      MonophaseStandardTaxResource = Data.define(:cbs_ad_rem_rate, :cbs_amount, :ibs_ad_rem_rate, :ibs_amount, :quantity_basis) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cbs_ad_rem_rate: payload["cbsAdRemRate"],
            cbs_amount: payload["cbsAmount"],
            ibs_ad_rem_rate: payload["ibsAdRemRate"],
            ibs_amount: payload["ibsAmount"],
            quantity_basis: payload["quantityBasis"],
          )
        end
      end
    end
  end
end
