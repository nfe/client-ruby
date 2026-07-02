# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      TaxCodePaginatedResponse = Data.define(:current_page, :items, :total_count, :total_pages) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            current_page: payload["currentPage"],
            items: (payload["items"] || []).map { |e| TaxCode.from_api(e) },
            total_count: payload["totalCount"],
            total_pages: payload["totalPages"],
          )
        end
      end
    end
  end
end
