# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      CalculateItemRequest = Data.define(:acquisition_purpose, :benefit, :cest, :discount_amount, :ex_tipi, :freight_amount, :gtin, :icms, :id, :ii, :insurance_amount, :issuer_tax_profile, :ncm, :operation_code, :origin, :others_amount, :quantity, :recipient_tax_profile, :sku, :unit_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            acquisition_purpose: payload["acquisitionPurpose"],
            benefit: payload["benefit"],
            cest: payload["cest"],
            discount_amount: payload["discountAmount"],
            ex_tipi: payload["exTipi"],
            freight_amount: payload["freightAmount"],
            gtin: payload["gtin"],
            icms: Icms.from_api(payload["icms"]),
            id: payload["id"],
            ii: Ii.from_api(payload["ii"]),
            insurance_amount: payload["insuranceAmount"],
            issuer_tax_profile: payload["issuerTaxProfile"],
            ncm: payload["ncm"],
            operation_code: payload["operationCode"],
            origin: payload["origin"],
            others_amount: payload["othersAmount"],
            quantity: payload["quantity"],
            recipient_tax_profile: payload["recipientTaxProfile"],
            sku: payload["sku"],
            unit_amount: payload["unitAmount"],
          )
        end
      end
    end
  end
end
