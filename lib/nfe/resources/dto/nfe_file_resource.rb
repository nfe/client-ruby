# frozen_string_literal: true

module Nfe
  # Immutable value object describing a downloadable file as returned by the
  # +api.nfse.io/v2+ product-invoice download endpoints, which respond with a
  # JSON envelope carrying a +uri+ to the file rather than the raw bytes.
  #
  # This is what distinguishes {Nfe::Resources::ProductInvoices} downloads
  # (which return a +NfeFileResource+) from the byte-returning downloads on the
  # other invoice resources. {from_api} maps camelCase keys onto snake_case
  # members, drops unknown keys, and is nil-tolerant.
  class NfeFileResource < Data.define(:uri, :name, :content_type, :size)
    # Build a {Nfe::NfeFileResource} from an API payload.
    #
    # @param payload [Hash, nil] the response object.
    # @return [Nfe::NfeFileResource, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        uri: payload["uri"] || payload["url"],
        name: payload["name"],
        content_type: payload["contentType"],
        size: payload["size"]
      )
    end
  end
end
