# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      ISSQNTotalResource = Data.define(:base_rate_iss, :code_tax_regime, :deduction_reduction_bc, :discount_conditioning, :discount_unconditional, :provision_service, :total_iss, :total_retention_iss, :total_service_not_taxed_icms, :value_other_retention, :value_service_cofins, :value_service_pis) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            base_rate_iss: payload["baseRateISS"],
            code_tax_regime: payload["codeTaxRegime"],
            deduction_reduction_bc: payload["deductionReductionBC"],
            discount_conditioning: payload["discountConditioning"],
            discount_unconditional: payload["discountUnconditional"],
            provision_service: payload["provisionService"],
            total_iss: payload["totalISS"],
            total_retention_iss: payload["totalRetentionISS"],
            total_service_not_taxed_icms: payload["totalServiceNotTaxedICMS"],
            value_other_retention: payload["valueOtherRetention"],
            value_service_cofins: payload["valueServiceCOFINS"],
            value_service_pis: payload["valueServicePIS"],
          )
        end
      end
    end
  end
end
