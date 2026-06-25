# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      RealEstate = Data.define(:cib_code, :property_fiscal_registration, :site_address) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cib_code: payload["cibCode"],
            property_fiscal_registration: payload["propertyFiscalRegistration"],
            site_address: AddressDefinition.from_api(payload["siteAddress"]),
          )
        end
      end
    end
  end
end
