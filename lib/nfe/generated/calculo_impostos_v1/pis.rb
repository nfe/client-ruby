# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      Pis = Data.define(:cst, :p_pis, :q_bcprod, :v_aliq_prod, :v_bc, :v_pis) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cst: payload["cst"],
            p_pis: payload["pPIS"],
            q_bcprod: payload["qBCProd"],
            v_aliq_prod: payload["vAliqProd"],
            v_bc: payload["vBC"],
            v_pis: payload["vPIS"],
          )
        end
      end
    end
  end
end
