# frozen_string_literal: true

module Nfe
  # Immutable value object for a natural person (pessoa física) tied to a
  # company. {from_api} maps API camelCase onto snake_case, drops unknown keys,
  # and is nil-tolerant.
  #
  # +federal_tax_number+ is kept as a +String+ (CPF), never coerced to Integer.
  class NaturalPerson < Data.define(
    :id,
    :name,
    :federal_tax_number,
    :email,
    :address,
    :created_on,
    :modified_on
  )
    # @param payload [Hash, nil] the unwrapped natural-person object.
    # @return [Nfe::NaturalPerson, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        name: payload["name"],
        federal_tax_number: payload["federalTaxNumber"]&.to_s,
        email: payload["email"],
        address: payload["address"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"]
      )
    end
  end
end
