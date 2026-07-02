# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      TransportRateResource = Data.define(:bc_retention_amount, :cfop, :city_generator_fact_code, :icms_retention_amount, :icms_retention_rate, :service_amount) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            bc_retention_amount: payload["bcRetentionAmount"],
            cfop: payload["cfop"],
            city_generator_fact_code: payload["cityGeneratorFactCode"],
            icms_retention_amount: payload["icmsRetentionAmount"],
            icms_retention_rate: payload["icmsRetentionRate"],
            service_amount: payload["serviceAmount"],
          )
        end
      end
    end
  end
end
