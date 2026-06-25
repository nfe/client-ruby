# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      CalculateItemResponse = Data.define(:additional_information, :benefit, :cest, :cfop, :cofins, :icms, :icms_uf_dest, :id, :ii, :ipi, :last_modified, :pis, :product_id) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            additional_information: payload["additionalInformation"],
            benefit: payload["benefit"],
            cest: payload["cest"],
            cfop: payload["cfop"],
            cofins: Cofins.from_api(payload["cofins"]),
            icms: Icms.from_api(payload["icms"]),
            icms_uf_dest: IcmsUfDest.from_api(payload["icmsUfDest"]),
            id: payload["id"],
            ii: Ii.from_api(payload["ii"]),
            ipi: Ipi.from_api(payload["ipi"]),
            last_modified: payload["lastModified"],
            pis: Pis.from_api(payload["pis"]),
            product_id: payload["productId"],
          )
        end
      end
    end
  end
end
