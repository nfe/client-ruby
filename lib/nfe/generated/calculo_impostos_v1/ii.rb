# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      Ii = Data.define(:inf_custo_aquis, :p_cred_sn, :v_bc, :v_cred_icmssn, :v_desp_adu, :v_enc_camb, :v_ii, :v_iof) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            inf_custo_aquis: payload["infCustoAquis"],
            p_cred_sn: payload["pCredSN"],
            v_bc: payload["vBC"],
            v_cred_icmssn: payload["vCredICMSSN"],
            v_desp_adu: payload["vDespAdu"],
            v_enc_camb: payload["vEncCamb"],
            v_ii: payload["vII"],
            v_iof: payload["vIOF"],
          )
        end
      end
    end
  end
end
