# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      TotalsWithholdings = Data.define(:cofins_amount, :csll_amount, :irrf_amount, :irrf_basis, :pis_amount, :social_secutiry_amount, :social_secutiry_basis) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cofins_amount: payload["cofinsAmount"],
            csll_amount: payload["csllAmount"],
            irrf_amount: payload["irrfAmount"],
            irrf_basis: payload["irrfBasis"],
            pis_amount: payload["pisAmount"],
            social_secutiry_amount: payload["socialSecutiryAmount"],
            social_secutiry_basis: payload["socialSecutiryBasis"],
          )
        end
      end
    end
  end
end
