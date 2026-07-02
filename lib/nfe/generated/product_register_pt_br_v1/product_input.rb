# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-register-pt-br-v1.yaml
# Hash: sha256:beba0a3fb4dc1bc157a5a4a28e55768cea0e7390b491bdd4bedee2ee2297ca64

module Nfe
  module Generated
    module ProductRegisterPtBrV1
      ProductInput = Data.define(:collection_id, :custom_tax, :description, :gtin, :origin, :sku, :tax, :tax_gtin, :tenant_id) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            collection_id: payload["collectionId"],
            custom_tax: (payload["customTax"] || []).map { |e| CustomTaxScenario.from_api(e) },
            description: payload["description"],
            gtin: payload["gtin"],
            origin: payload["origin"],
            sku: payload["sku"],
            tax: payload["tax"],
            tax_gtin: payload["taxGtin"],
            tenant_id: payload["tenantId"],
          )
        end
      end
    end
  end
end
