# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-servico-v1.yaml
# Hash: sha256:621a3b8e437e5cb37367c8cd26fec93fa2b3f87c9a59252ac987c56bb0c7ba56

module Nfe
  module Generated
    module NfServicoV1
      ErrorsResource = Data.define(:errors) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            errors: payload["errors"],
          )
        end
      end
    end
  end
end
