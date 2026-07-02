# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      InvoiceItemTaxResource = Data.define(:ibscbs, :is, :cofins, :competence_adjustment, :icms, :icms_destination, :ii, :ipi, :pis, :total_tax) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            ibscbs: IBSCBSTaxResource.from_api(payload["IBSCBS"]),
            is: ISTaxResource.from_api(payload["IS"]),
            cofins: CofinsTaxResource.from_api(payload["cofins"]),
            competence_adjustment: CompetenceAdjustmentResource.from_api(payload["competenceAdjustment"]),
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
