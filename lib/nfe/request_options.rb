# frozen_string_literal: true

module Nfe
  # Immutable per-call overrides for a single request. Passing a
  # +RequestOptions+ to {Nfe::Client#request} (or through a resource helper)
  # overrides the family-resolved +api_key+, +base_url+, and +timeout+ for that
  # one call; any nil field falls back to normal family resolution.
  #
  # This enables multi-tenant per-call keys without constructing a second
  # +Nfe::Client+.
  class RequestOptions < Data.define(:api_key, :base_url, :timeout)
    def initialize(api_key: nil, base_url: nil, timeout: nil)
      super
    end
  end
end
