# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-dfe-distribuicao-v2.yaml
# Hash: sha256:f607124386b9d5210012cd4ac84ed7a0e359939e4176cebe4103b5a525321bdd

module Nfe
  module Generated
    module ConsultaDfeDistribuicaoV2
      IssuerResource = Data.define(:federal_tax_number, :name) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            federal_tax_number: payload["federalTaxNumber"],
            name: payload["name"],
          )
        end
      end
    end
  end
end
