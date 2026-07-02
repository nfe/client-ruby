# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      TotalResource = Data.define(:icms, :issqn) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            icms: ICMSTotalResource.from_api(payload["icms"]),
            issqn: ISSQNTotalResource.from_api(payload["issqn"]),
          )
        end
      end
    end
  end
end
