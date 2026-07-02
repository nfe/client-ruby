# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      DocumentInvoiceReferenceResource = Data.define(:federal_tax_number, :model, :number, :series, :state, :year_month) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            federal_tax_number: payload["federalTaxNumber"],
            model: payload["model"],
            number: payload["number"],
            series: payload["series"],
            state: payload["state"],
            year_month: payload["yearMonth"],
          )
        end
      end
    end
  end
end
