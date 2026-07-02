# frozen_string_literal: true

module Nfe
  # Immutable value object for a company's state-tax (Inscrição Estadual)
  # registration entry, as returned by the CT-e +api.nfse.io+ state-tax API
  # under +/v2/companies/{companyId}/statetaxes+.
  #
  # Hand-written: the generated +contribuintes-v2+ model lives under a different
  # namespace/shape, so this top-level {Nfe::NfeStateTax} mirrors only the
  # fields the Node/PHP SDKs read. {from_api} maps the API camelCase keys onto
  # snake_case members, drops unknown keys, and is nil-tolerant
  # (+from_api(nil)+ returns +nil+). All fields are optional.
  class NfeStateTax < Data.define(
    :id,
    :tax_number,
    :serie,
    :number,
    :code,
    :environment_type,
    :type,
    :status
  )
    # Build a {Nfe::NfeStateTax} from an API payload.
    #
    # @param payload [Hash, nil] the response object.
    # @return [Nfe::NfeStateTax, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        id: payload["id"],
        tax_number: payload["taxNumber"],
        serie: payload["serie"],
        number: payload["number"],
        code: payload["code"],
        environment_type: payload["environmentType"],
        type: payload["type"],
        status: payload["status"]
      )
    end
  end
end
