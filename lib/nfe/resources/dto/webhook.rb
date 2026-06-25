# frozen_string_literal: true

module Nfe
  # Immutable value object for a persisted webhook subscription, as returned by
  # the +/companies/{id}/webhooks+ entity API.
  #
  # NOTE ON NAMING: the spec text refers to this DTO as "Nfe::Webhook", but that
  # constant is reserved for the canonical signature-verification module
  # ({Nfe::Webhook}, +lib/nfe/webhook.rb+). A Ruby +module+ and a +class+ cannot
  # share a constant, so the subscription DTO is named +Nfe::WebhookSubscription+.
  # Resources hydrating a webhook subscription (+Nfe::Resources::Webhooks+) MUST
  # hydrate this class.
  #
  # {from_api} maps API camelCase onto snake_case, drops unknown keys, and is
  # nil-tolerant (+from_api(nil)+ returns +nil+).
  class WebhookSubscription < Data.define(
    :id,
    :url,
    :events,
    :secret,
    :active,
    :status,
    :created_on,
    :modified_on
  )
    # @param payload [Hash, nil] the unwrapped webhook object.
    # @return [Nfe::WebhookSubscription, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        url: payload["url"],
        events: payload["events"],
        secret: payload["secret"],
        active: payload["active"],
        status: payload["status"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"]
      )
    end
  end
end
