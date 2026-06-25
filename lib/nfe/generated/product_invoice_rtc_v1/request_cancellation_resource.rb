# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      RequestCancellationResource = Data.define(:account_id, :company_id, :product_invoice_id, :reason) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            company_id: payload["companyId"],
            product_invoice_id: payload["productInvoiceId"],
            reason: payload["reason"],
          )
        end
      end
    end
  end
end
