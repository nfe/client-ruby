# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nfeio.yaml
# Hash: sha256:813bda287538f8599c3565485eb523d1b1311b26b5be94ead62ba0b7a17f6af3

module Nfe
  module Generated
    module Nfeio
      BatchProcessResponse = Data.define(:created_at, :input, :out_puts, :status, :status_reason, :updated_at) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            created_at: payload["createdAt"],
            input: payload["input"],
            out_puts: (payload["outPuts"] || []).map { |e| OutPutResponse.from_api(e) },
            status: payload["status"],
            status_reason: payload["statusReason"],
            updated_at: payload["updatedAt"],
          )
        end
      end
    end
  end
end
