# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      ReferencedProcessResource = Data.define(:concession_act_type, :identifier_concessory, :identifier_origin) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            concession_act_type: payload["concessionActType"],
            identifier_concessory: payload["identifierConcessory"],
            identifier_origin: payload["identifierOrigin"],
          )
        end
      end
    end
  end
end
