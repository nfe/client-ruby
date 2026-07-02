# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      IcmsUfDest = Data.define(:p_fcpufdest, :p_icmsinter, :p_icmsinter_part, :p_icmsufdest, :v_bcfcpufdest, :v_bcufdest, :v_fcpufdest, :v_icmsufdest, :v_icmsufremet) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            p_fcpufdest: payload["pFCPUFDest"],
            p_icmsinter: payload["pICMSInter"],
            p_icmsinter_part: payload["pICMSInterPart"],
            p_icmsufdest: payload["pICMSUFDest"],
            v_bcfcpufdest: payload["vBCFCPUFDest"],
            v_bcufdest: payload["vBCUFDest"],
            v_fcpufdest: payload["vFCPUFDest"],
            v_icmsufdest: payload["vICMSUFDest"],
            v_icmsufremet: payload["vICMSUFRemet"],
          )
        end
      end
    end
  end
end
