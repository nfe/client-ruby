# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      ProductInvoiceEventsResource = Data.define(:account_id, :company_id, :events, :has_more, :id) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            account_id: payload["accountId"],
            company_id: payload["companyId"],
            events: (payload["events"] || []).map { |e| ActivityResource.from_api(e) },
            has_more: payload["hasMore"],
            id: payload["id"],
          )
        end
      end
    end
  end
end
