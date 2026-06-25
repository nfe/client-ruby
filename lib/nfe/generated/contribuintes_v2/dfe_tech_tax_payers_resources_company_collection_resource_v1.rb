# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      DFeTech_TaxPayers_Resources_CompanyCollectionResourceV1 = Data.define(:companies, :page, :total_pages, :total_results) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            companies: (payload["companies"] || []).map { |e| DFeTech_TaxPayers_Resources_CompanyResourceV1.from_api(e) },
            page: payload["page"],
            total_pages: payload["totalPages"],
            total_results: payload["totalResults"],
          )
        end
      end
    end
  end
end
