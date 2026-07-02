# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      PumpResource = Data.define(:beginning_amount, :end_amount, :number, :percentage_bio, :spout_number, :tank_number) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            beginning_amount: payload["beginningAmount"],
            end_amount: payload["endAmount"],
            number: payload["number"],
            percentage_bio: payload["percentageBio"],
            spout_number: payload["spoutNumber"],
            tank_number: payload["tankNumber"],
          )
        end
      end
    end
  end
end
