# frozen_string_literal: true

module Nfe
  # Immutable value object for a consumer invoice (NFC-e — Nota Fiscal de
  # Consumidor Eletrônica) emitted through the NFE.io +api.nfse.io+ v2 API.
  #
  # Hand-written (rather than reusing the verbose generated +nf-consumidor-v2+
  # DTOs) so the public shape stays clean and snake_case. {from_api} maps the
  # API camelCase keys onto the snake_case members, drops unknown keys, and is
  # nil-tolerant (+from_api(nil)+ returns +nil+). The full parsed payload is
  # preserved under +raw+ for forward compatibility.
  #
  # Shape mirrors +POST /v2/companies/{id}/consumerinvoices+ and
  # +GET .../consumerinvoices/{id}+ per +nf-consumidor-v2.yaml+.
  #
  # +number+/+serie+ are kept as returned (no Integer coercion) so leading
  # zeros and string representations from the API survive untouched.
  class ConsumerInvoice < Data.define(
    :id,
    :status,
    :flow_status,
    :flow_message,
    :environment,
    :access_key,
    :number,
    :serie,
    :total_amount,
    :issued_on,
    :created_on,
    :modified_on,
    :cancelled_on,
    :raw
  )
    # Build a {Nfe::ConsumerInvoice} from an API payload.
    #
    # @param payload [Hash, nil] the parsed consumer-invoice object.
    # @return [Nfe::ConsumerInvoice, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        status: payload["status"],
        flow_status: payload["flowStatus"],
        flow_message: payload["flowMessage"],
        environment: payload["environment"],
        access_key: payload["accessKey"],
        number: payload["number"],
        serie: payload["serie"],
        total_amount: payload["totalAmount"],
        issued_on: payload["issuedOn"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"],
        cancelled_on: payload["cancelledOn"],
        raw: payload
      )
    end
  end
end
