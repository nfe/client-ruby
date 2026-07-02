# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      InvoiceItemsResource = Data.define(:account_id, :company_id, :has_more, :id, :items) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            company_id: payload["companyId"],
            has_more: payload["hasMore"],
            id: payload["id"],
            items: (payload["items"] || []).map { |e| InvoiceItemResource.from_api(e) },
          )
        end
      end
    end
  end
end
