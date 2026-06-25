# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      WithdrawalInformationResource = Data.define(:account_id, :address, :email, :federal_tax_number, :id, :name, :state_tax_number, :type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            address: AddressResource.from_api(payload["address"]),
            email: payload["email"],
            federal_tax_number: payload["federalTaxNumber"],
            id: payload["id"],
            name: payload["name"],
            state_tax_number: payload["stateTaxNumber"],
            type: payload["type"],
          )
        end
      end
    end
  end
end
