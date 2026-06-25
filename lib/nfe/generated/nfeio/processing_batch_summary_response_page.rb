# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nfeio.yaml
# Hash: sha256:813bda287538f8599c3565485eb523d1b1311b26b5be94ead62ba0b7a17f6af3

module Nfe
  module Generated
    module Nfeio
      ProcessingBatchSummaryResponsePage = Data.define(:has_next, :has_previous, :items, :next_cursor, :previous_cursor) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            has_next: payload["hasNext"],
            has_previous: payload["hasPrevious"],
            items: (payload["items"] || []).map { |e| ProcessingBatchSummaryResponse.from_api(e) },
            next_cursor: GuidPaginationCursor.from_api(payload["nextCursor"]),
            previous_cursor: GuidPaginationCursor.from_api(payload["previousCursor"]),
          )
        end
      end
    end
  end
end
