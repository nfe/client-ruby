# frozen_string_literal: true

module Nfe
  # Immutable value object for a legal person (pessoa jurídica) tied to a
  # company. {from_api} maps API camelCase onto snake_case, drops unknown keys,
  # and is nil-tolerant.
  #
  # +federal_tax_number+ is kept as a +String+ (CNPJ), never coerced to Integer.
  class LegalPerson < Data.define(
    :id,
    :name,
    :trade_name,
    :federal_tax_number,
    :email,
    :address,
    :created_on,
    :modified_on
  )
    # @param payload [Hash, nil] the unwrapped legal-person object.
    # @return [Nfe::LegalPerson, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        name: payload["name"],
        trade_name: payload["tradeName"],
        federal_tax_number: payload["federalTaxNumber"]&.to_s,
        email: payload["email"],
        address: payload["address"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"]
      )
    end
  end
end
