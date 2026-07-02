# frozen_string_literal: true

module Nfe
  # Immutable value object for the inbound auto-fetch settings returned by the
  # CT-e / inbound NF-e endpoints on +api.nfse.io+
  # (+/v2/companies/{id}/inbound/(transportation|product)invoices+).
  #
  # Hand-written (the +consulta-cte-v2+ generated tree does not expose a clean
  # settings shape) so the public surface stays small and snake_case.
  # {from_api} maps the API camelCase keys onto the snake_case members, drops
  # unknown keys, and is nil-tolerant (+from_api(nil)+ returns +nil+). The raw
  # payload is preserved in +details+ so callers can read fields the SDK does
  # not surface yet.
  class InboundSettings < Data.define(
    :id,
    :status,
    :start_from_nsu,
    :start_from_date,
    :environment_sefaz,
    :automatic_manifesting,
    :webhook_version,
    :created_on,
    :modified_on,
    :details
  )
    # Build a {Nfe::InboundSettings} from an API payload.
    #
    # @param payload [Hash, nil] the inbound settings object.
    # @return [Nfe::InboundSettings, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        status: payload["status"],
        start_from_nsu: payload["startFromNsu"],
        start_from_date: payload["startFromDate"],
        environment_sefaz: payload["environmentSefaz"] || payload["environmentSEFAZ"],
        automatic_manifesting: payload["automaticManifesting"],
        webhook_version: payload["webhookVersion"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"],
        details: payload
      )
    end
  end
end
