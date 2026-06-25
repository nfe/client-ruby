# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      TaxDeterminationResource = Data.define(:acquisition_purpose, :buyer_tax_profile, :issuer_tax_profile, :operation_code, :origin) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            acquisition_purpose: payload["acquisitionPurpose"],
            buyer_tax_profile: payload["buyerTaxProfile"],
            issuer_tax_profile: payload["issuerTaxProfile"],
            operation_code: payload["operationCode"],
            origin: payload["origin"],
          )
        end
      end
    end
  end
end
