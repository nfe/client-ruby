# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      Construction = Data.define(:cib_code, :encapsulation_number, :property_fiscal_registration, :site_address, :work_id) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cib_code: payload["cibCode"],
            encapsulation_number: payload["encapsulationNumber"],
            property_fiscal_registration: payload["propertyFiscalRegistration"],
            site_address: AddressDefinition.from_api(payload["siteAddress"]),
            work_id: payload["workId"],
          )
        end
      end
    end
  end
end
