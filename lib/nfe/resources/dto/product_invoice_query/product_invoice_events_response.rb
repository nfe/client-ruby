# frozen_string_literal: true

module Nfe
  # Immutable value object for the events (eventos) associated with a product
  # invoice (NF-e), fetched from the +nfe.api.nfe.io+ query API by access key.
  #
  # Hand-written (the +consulta_nfe_distribuicao_v1+ generated schema does not
  # cover this shape). {from_api} maps API camelCase keys onto snake_case
  # members, drops unknown keys, and is nil-tolerant (+from_api(nil)+ returns
  # +nil+). All fields are optional.
  #
  # +events+ is kept as the raw payload array (free-form event bodies); a
  # missing list normalizes to +[]+.
  class ProductInvoiceEventsResponse < Data.define(
    :events,
    :created_on
  )
    # Build a {Nfe::ProductInvoiceEventsResponse} from an API payload.
    #
    # @param payload [Hash, nil] the response object.
    # @return [Nfe::ProductInvoiceEventsResponse, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        events: payload["events"] || [],
        created_on: payload["createdOn"]
      )
    end
  end
end
