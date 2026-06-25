# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      FuelOriginResource = Data.define(:c_uforig, :ind_import, :p_orig) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            c_uforig: payload["cUFOrig"],
            ind_import: payload["indImport"],
            p_orig: payload["pOrig"],
          )
        end
      end
    end
  end
end
