# frozen_string_literal: true

module Nfe
  # Immutable value object for a service invoice (NFS-e) as returned by the
  # NFE.io +api.nfe.io/v1+ service-invoice API.
  #
  # The +nf-servico-v1.yaml+ OpenAPI spec defines NO component schemas (the
  # shape is derived from the operations), so this DTO is hand-written — mirror
  # of the fields the Node/PHP SDKs read. {from_api} maps the API camelCase keys
  # onto snake_case members, drops unknown keys, and is nil-tolerant
  # (+from_api(nil)+ returns +nil+).
  #
  # +flow_status+ drives the polling lifecycle; pass it to
  # {Nfe::FlowStatus.terminal?} to decide when the document is settled.
  class ServiceInvoice < Data.define(
    :id,
    :flow_status,
    :flow_message,
    :status,
    :environment,
    :rps_number,
    :rps_serial_number,
    :number,
    :check_code,
    :issued_on,
    :cancelled_on,
    :amount_net,
    :services_amount,
    :borrower,
    :city_service_code,
    :federal_service_code,
    :description,
    :pdf,
    :xml,
    :created_on,
    :modified_on
  )
    # Build a {Nfe::ServiceInvoice} from an API payload.
    #
    # @param payload [Hash, nil] the response object.
    # @return [Nfe::ServiceInvoice, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        flow_status: payload["flowStatus"],
        flow_message: payload["flowMessage"],
        status: payload["status"],
        environment: payload["environment"],
        rps_number: payload["rpsNumber"],
        rps_serial_number: payload["rpsSerialNumber"],
        number: payload["number"],
        check_code: payload["checkCode"],
        issued_on: payload["issuedOn"],
        cancelled_on: payload["cancelledOn"],
        amount_net: payload["amountNet"],
        services_amount: payload["servicesAmount"],
        borrower: payload["borrower"],
        city_service_code: payload["cityServiceCode"],
        federal_service_code: payload["federalServiceCode"],
        description: payload["description"],
        pdf: payload["pdf"],
        xml: payload["xml"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"]
      )
    end
  end
end
