# frozen_string_literal: true

module Nfe
  # Immutable value object for an account-level webhook, as returned by the
  # +/v2/webhooks+ API (account scope, envelope +{"webHook": {...}}+ on the
  # wire). This is the shape the live API accepts and returns — confirmed by
  # probe against +api.nfe.io+ (2026-07-02/03) and matching the schema in
  # +openapi/nf-servico-v1.yaml+.
  #
  # Wire-format note: the OpenAPI spec declares +contentType+/+status+ as int
  # enums (0/1), but the API serializes strings (+"json"+, +"Active"+) — this
  # DTO follows the wire. +secret+ (32–64 chars) is echoed only on create and
  # omitted on reads, so it is +nil+ on retrieve/list.
  #
  # {from_api} maps API camelCase onto snake_case, drops unknown keys, and is
  # nil-tolerant (+from_api(nil)+ returns +nil+).
  class AccountWebhook < Data.define(
    :id,
    :uri,
    :content_type,
    :secret,
    :filters,
    :insecure_ssl,
    :headers,
    :properties,
    :status,
    :created_on,
    :modified_on
  )
    # @param payload [Hash, nil] the unwrapped webhook object.
    # @return [Nfe::AccountWebhook, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        uri: payload["uri"],
        content_type: payload["contentType"],
        secret: payload["secret"],
        filters: payload["filters"],
        insecure_ssl: payload["insecureSsl"],
        headers: payload["headers"],
        properties: payload["properties"],
        status: payload["status"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"]
      )
    end
  end
end
