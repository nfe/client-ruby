# frozen_string_literal: true

module Nfe
  # Immutable value object for a company (emitente) as returned by the NFE.io
  # +api.nfe.io/v1+ entity API.
  #
  # Hand-written (rather than reusing the mangled generated +contribuintes_v2+
  # DTOs) so the public shape stays clean and snake_case. {from_api} maps the
  # API camelCase keys onto the snake_case members, drops unknown keys, and is
  # nil-tolerant (+from_api(nil)+ returns +nil+).
  #
  # +federal_tax_number+ is kept as a +String+ — never coerced to +Integer+ —
  # so future alphanumeric CNPJ (IN RFB 2.229/2024) is preserved.
  class Company < Data.define(
    :id,
    :name,
    :trade_name,
    :federal_tax_number,
    :email,
    :status,
    :tax_regime,
    :municipal_tax_number,
    :address,
    :state_taxes,
    :municipal_taxes,
    :environment,
    :account_id,
    :created_on,
    :modified_on
  )
    # Build a {Nfe::Company} from an API payload.
    #
    # @param payload [Hash, nil] the unwrapped company object.
    # @return [Nfe::Company, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        name: payload["name"],
        trade_name: payload["tradeName"],
        federal_tax_number: stringify(payload["federalTaxNumber"]),
        email: payload["email"],
        status: payload["status"],
        tax_regime: payload["taxRegime"],
        municipal_tax_number: payload["municipalTaxNumber"],
        address: payload["address"],
        state_taxes: payload["stateTaxes"],
        municipal_taxes: payload["municipalTaxes"],
        environment: payload["environment"],
        account_id: payload["accountId"],
        created_on: payload["createdOn"],
        modified_on: payload["modifiedOn"]
      )
    end

    # Coerce a tax number to a +String+ without numeric coercion, preserving
    # alphanumeric CNPJ. +nil+ stays +nil+.
    #
    # @api private
    def self.stringify(value)
      value&.to_s
    end
  end
end
