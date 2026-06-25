# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      Ipi = Data.define(:c_enq, :cst, :p_ipi, :q_unid, :v_bc, :v_ipi, :v_unid) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            c_enq: payload["cEnq"],
            cst: payload["cst"],
            p_ipi: payload["pIPI"],
            q_unid: payload["qUnid"],
            v_bc: payload["vBC"],
            v_ipi: payload["vIPI"],
            v_unid: payload["vUnid"],
          )
        end
      end
    end
  end
end
