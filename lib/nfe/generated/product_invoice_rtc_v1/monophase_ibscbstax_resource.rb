# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
