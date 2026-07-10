# frozen_string_literal: true

require "nfe/resources/dto/service_invoice_borrower"

module Nfe
  # Immutable value object for a service invoice (NFS-e) as returned by the
  # NFE.io +api.nfe.io/v1+ service-invoice API.
  #
  # The +nf-servico-v1.yaml+ OpenAPI spec declares the retrieve success
  # response **inline** (no named schema in +components.schemas+ — only the
  # error model is componentized), so this DTO is hand-written and pinned to
  # the spec by an alignment test. {from_api} maps the API camelCase keys onto
  # snake_case members and is nil-tolerant (+from_api(nil)+ returns +nil+).
  # The full parsed payload is preserved under +raw+ for forward
  # compatibility — fields without a typed member (the withholding tree,
  # +provider+, +taxationType+, +location+, +approximateTax+, ...) are
  # accessible through it.
  #
  # +borrower+ is hydrated into {Nfe::ServiceInvoiceBorrower} (typed readers
  # plus a Hash-compatibility bridge, so +borrower["name"]+ keeps working).
  #
  # +flow_status+ drives the polling lifecycle; pass it to
  # {Nfe::FlowStatus.terminal?} to decide when the document is settled.
  #
  # @!attribute [r] pdf
  #   @deprecated Ghost field — the retrieve response carries no +pdf+ key
  #     (always +nil+). Use {Nfe::Resources::ServiceInvoices#download_pdf}.
  # @!attribute [r] xml
  #   @deprecated Ghost field — the retrieve response carries no +xml+ key
  #     (always +nil+). Use {Nfe::Resources::ServiceInvoices#download_xml}.
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
    :modified_on,
    :base_tax_amount,
    :iss_rate,
    :iss_tax_amount,
    :raw
  )
    # Build a {Nfe::ServiceInvoice} from an API payload.
    #
    # @param payload [Hash, nil] the response object.
    # @return [Nfe::ServiceInvoice, nil] +nil+ when +payload+ is +nil+.
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize -- wide value-object mapping kept inline for Steep keyword-arg verification
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
        borrower: ServiceInvoiceBorrower.from_api(payload["borrower"]),
        city_service_code: payload["cityServiceCode"],
        federal_service_code: payload["federalServiceCode"],
        description: payload["description"],
        pdf: payload["pdf"],
        xml: payload["xml"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"],
        base_tax_amount: payload["baseTaxAmount"],
        iss_rate: payload["issRate"],
        iss_tax_amount: payload["issTaxAmount"],
        raw: payload
      )
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
end
