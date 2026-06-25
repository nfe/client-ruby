# frozen_string_literal: true

module Nfe
  # Immutable value object for a single address as returned by the NFE.io
  # +address.api.nfe.io/v2+ lookup API. All fields are optional; {from_api}
  # maps API camelCase keys onto snake_case members and is nil-tolerant
  # (+from_api(nil)+ returns +nil+).
  #
  # +city+ is hydrated into a nested {Nfe::Address::City} value object
  # (+{code, name}+). +postal_code+, +number+, +number_min+ and +number_max+
  # are kept as +String+, never coerced to Integer (preserves leading zeros).
  class Address < Data.define(
    :street,
    :street_suffix,
    :number,
    :number_min,
    :number_max,
    :additional_information,
    :district,
    :postal_code,
    :city,
    :state,
    :country
  )
    # Nested value object for the IBGE city code/name pair returned inside an
    # address item. Both members are optional and nil-tolerant.
    class City < Data.define(:code, :name)
      # @param payload [Hash, nil] the +city+ sub-object.
      # @return [Nfe::Address::City, nil] +nil+ when +payload+ is +nil+.
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          code: payload["code"]&.to_s,
          name: payload["name"]
        )
      end
    end

    # @param payload [Hash, nil] a single address object.
    # @return [Nfe::Address, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        street: payload["street"],
        street_suffix: payload["streetSuffix"],
        number: payload["number"]&.to_s,
        number_min: payload["numberMin"]&.to_s,
        number_max: payload["numberMax"]&.to_s,
        additional_information: payload["additionalInformation"],
        district: payload["district"],
        postal_code: payload["postalCode"]&.to_s,
        city: Nfe::Address::City.from_api(payload["city"]),
        state: payload["state"],
        country: payload["country"]
      )
    end
  end

  # Immutable value object wrapping the list of addresses returned by an
  # address lookup. {from_api} hydrates each item of the API +addresses+
  # array into an {Nfe::Address} and is nil-tolerant.
  class AddressLookupResponse < Data.define(:addresses)
    # @param payload [Hash, nil] the parsed lookup response body.
    # @return [Nfe::AddressLookupResponse, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        addresses: (payload["addresses"] || []).map { |item| Nfe::Address.from_api(item) }
      )
    end
  end
end
