# frozen_string_literal: true

module Nfe
  # Immutable value object for a verified webhook delivery, produced by
  # {Nfe::Webhook.construct_event} after the HMAC-SHA1 signature checks out.
  #
  # - +type+ is the event type (e.g. +"service_invoice.issued_successfully"+), unwrapped from the
  #   delivery envelope's +action+ or +event+ key.
  # - +data+ is the payload +Hash+ (the envelope's +payload+ or +data+ key).
  # - +id+ is a stable event/invoice id for deduplication, or +nil+ when the
  #   envelope carries none. NFE.io sends no timestamp/nonce, so a valid
  #   signature proves authenticity but NOT freshness — handlers MUST be
  #   idempotent and dedupe on this id.
  # - +created_at+ is the delivery timestamp string, or +nil+.
  class WebhookEvent < Data.define(:type, :data, :id, :created_at)
    # Allow +id+ and +created_at+ to default to +nil+ so callers (and
    # +construct_event+) can omit them.
    def initialize(type:, data:, id: nil, created_at: nil)
      super
    end
  end
end
