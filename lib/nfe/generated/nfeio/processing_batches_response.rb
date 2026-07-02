# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nfeio.yaml
# Hash: sha256:813bda287538f8599c3565485eb523d1b1311b26b5be94ead62ba0b7a17f6af3

module Nfe
  module Generated
    module Nfeio
      ProcessingBatchesResponse = Data.define(:created_at, :id, :status, :updated_at) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            created_at: payload["createdAt"],
            id: payload["id"],
            status: payload["status"],
            updated_at: payload["updatedAt"],
          )
        end
      end
    end
  end
end
