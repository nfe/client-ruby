# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nfeio.yaml
# Hash: sha256:813bda287538f8599c3565485eb523d1b1311b26b5be94ead62ba0b7a17f6af3

module Nfe
  module Generated
    module Nfeio
      OutPutResponse = Data.define(:out_put_link, :status, :type) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            out_put_link: OutPutLinkResponse.from_api(payload["outPutLink"]),
            status: payload["status"],
            type: payload["type"],
          )
        end
      end
    end
  end
end
