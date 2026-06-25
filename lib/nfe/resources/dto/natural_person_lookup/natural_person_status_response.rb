# frozen_string_literal: true

module Nfe
  # Immutable value object for the result of a natural-person (CPF) status
  # lookup against the +naturalperson+ data API. {from_api} maps API camelCase
  # onto snake_case, drops unknown keys, and is nil-tolerant. All fields are
  # optional.
  #
  # +federal_tax_number+ is kept as a +String+ (CPF), never coerced to Integer.
  class NaturalPersonStatusResponse < Data.define(
    :name,
    :federal_tax_number,
    :birth_on,
    :status,
    :created_on
  )
    # @param payload [Hash, nil] the unwrapped status object.
    # @return [Nfe::NaturalPersonStatusResponse, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        name: payload["name"],
        federal_tax_number: payload["federalTaxNumber"]&.to_s,
        birth_on: payload["birthOn"],
        status: payload["status"],
        created_on: payload["createdOn"]
      )
    end
  end
end
