# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      ICMSUFDestinationTaxResource = Data.define(:p_fcpufdest, :p_icmsinter, :p_icmsinter_part, :p_icmsufdest, :v_bcfcpufdest, :v_bcufdest, :v_fcpufdest, :v_icmsufdest, :v_icmsufremet) do
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
