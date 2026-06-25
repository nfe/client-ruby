# frozen_string_literal: true

module Nfe
  # Immutable value object for a product invoice (NF-e) as returned by the
  # NFE.io +api.nfse.io/v2+ product-invoice API.
  #
  # Hand-written (rather than reusing the verbose/mangled generated
  # +nf_produto_v2+ DTO names) so the public shape stays clean and snake_case.
  # {from_api} maps the API camelCase keys onto snake_case members, drops
  # unknown keys, and is nil-tolerant (+from_api(nil)+ returns +nil+).
  #
  # +flow_status+ drives the polling lifecycle; pass it to
  # {Nfe::FlowStatus.terminal?} to decide when the document is settled.
  class ProductInvoice < Data.define(
    :id,
    :flow_status,
    :flow_message,
    :status,
    :environment,
    :serie,
    :number,
    :operation_nature,
    :operation_type,
    :access_key,
    :protocol,
    :buyer,
    :items,
    :totals,
    :issued_on,
    :created_on,
    :modified_on
  )
    # Build a {Nfe::ProductInvoice} from an API payload.
    #
    # @param payload [Hash, nil] the response object.
    # @return [Nfe::ProductInvoice, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        flow_status: payload["flowStatus"],
        flow_message: payload["flowMessage"],
        status: payload["status"],
        environment: payload["environment"],
        serie: payload["serie"],
        number: payload["number"],
        operation_nature: payload["operationNature"],
        operation_type: payload["operationType"],
        access_key: payload["accessKey"],
        protocol: payload["protocol"],
        buyer: payload["buyer"],
        items: payload["items"],
        totals: payload["totals"],
        issued_on: payload["issuedOn"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"]
      )
    end
  end
end
