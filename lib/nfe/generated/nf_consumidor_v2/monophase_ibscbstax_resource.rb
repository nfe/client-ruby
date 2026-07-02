# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      MonophaseIBSCBSTaxResource = Data.define(:cbs_amount, :deferment, :ibs_amount, :previously_withheld, :standart, :withholding) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cbs_amount: payload["cbsAmount"],
            deferment: MonophaseDefermentTaxResource.from_api(payload["deferment"]),
            ibs_amount: payload["ibsAmount"],
            previously_withheld: MonophasePreviouslyWithheldTaxResource.from_api(payload["previouslyWithheld"]),
            standart: MonophaseStandardTaxResource.from_api(payload["standart"]),
            withholding: MonophaseWithholdingTaxResource.from_api(payload["withholding"]),
          )
        end
      end
    end
  end
end
