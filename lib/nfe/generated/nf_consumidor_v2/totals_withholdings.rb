# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
