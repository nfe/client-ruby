# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      InvoiceItemTaxResource = Data.define(:cofins, :icms, :icms_destination, :ii, :ipi, :pis, :total_tax) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cofins: CofinsTaxResource.from_api(payload["cofins"]),
            icms: IcmsTaxResource.from_api(payload["icms"]),
            icms_destination: ICMSUFDestinationTaxResource.from_api(payload["icmsDestination"]),
            ii: IITaxResource.from_api(payload["ii"]),
            ipi: IPITaxResource.from_api(payload["ipi"]),
            pis: PISTaxResource.from_api(payload["pis"]),
            total_tax: payload["totalTax"],
          )
        end
      end
    end
  end
end
