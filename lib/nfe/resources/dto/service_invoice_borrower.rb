# frozen_string_literal: true

require "nfe/resources/dto/company"

module Nfe
  # Immutable value object for the borrower (tomador) of a service invoice,
  # as embedded in the NFS-e retrieve response (+nf-servico-v1.yaml+, inline
  # schema of +GET /v1/companies/{company_id}/serviceinvoices/{id}+).
  #
  # +federal_tax_number+ is normalized to +String+ via {Nfe::Company.stringify}:
  # the spec declares it +integer int64+, but the alphanumeric CNPJ
  # (IN RFB 2.229/2024) requires string tolerance — deliberate deviation,
  # pinned by the alignment test. +address+ stays a raw +Hash+.
  #
  # Hash-compatibility bridge: before this DTO existed, +invoice.borrower+
  # returned the raw wire +Hash+ — {#[]} and {#dig} delegate to {#raw} so
  # +borrower["name"]+ keeps working alongside the typed readers.
  class ServiceInvoiceBorrower < Data.define(
    :id,
    :name,
    :federal_tax_number,
    :email,
    :phone_number,
    :address,
    :parent_id,
    :raw
  )
    # Build a {Nfe::ServiceInvoiceBorrower} from an API payload.
    #
    # @param payload [Hash, nil] the borrower object from the wire.
    # @return [Nfe::ServiceInvoiceBorrower, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        name: payload["name"],
        federal_tax_number: Company.stringify(payload["federalTaxNumber"]),
        email: payload["email"],
        phone_number: payload["phoneNumber"],
        address: payload["address"],
        parent_id: payload["parentId"],
        raw: payload
      )
    end

    # Hash-style read, delegated to the raw wire payload (camelCase keys),
    # e.g. +borrower["federalTaxNumber"]+ returns the wire value untouched.
    def [](key)
      raw && raw[key]
    end

    # Hash-style nested read over the raw wire payload,
    # e.g. +borrower.dig("address", "city", "name")+.
    def dig(*keys)
      raw&.dig(*keys)
    end
  end
end
