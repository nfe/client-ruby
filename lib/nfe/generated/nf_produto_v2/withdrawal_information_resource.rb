# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
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
