# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
