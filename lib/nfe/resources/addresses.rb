# frozen_string_literal: true

require "cgi"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/addresses/address_lookup_response"

module Nfe
  module Resources
    # Address lookup against the +:addresses+ data family
    # (+address.api.nfe.io/v2+). The host already embeds the API version, so
    # {#api_version} is +""+ and request paths are used verbatim.
    #
    # All three lookups return an {Nfe::AddressLookupResponse} wrapping the API
    # +addresses+ array.
    class Addresses < AbstractResource
      # Look up addresses by Brazilian postal code (CEP).
      #
      # @param postal_code [String] CEP in any format (e.g. +"01310-100"+).
      # @return [Nfe::AddressLookupResponse]
      # @raise [Nfe::InvalidRequestError] when the CEP is not 8 digits.
      def lookup_by_postal_code(postal_code)
        cep = Nfe::IdValidator.cep(postal_code)
        response = get("/addresses/#{cep}")
        hydrate(Nfe::AddressLookupResponse, parse_json(response.body))
      end

      # Search addresses with an opaque OData +$filter+ expression.
      #
      # @param filter [String, nil] forwarded as +$filter+ when present.
      # @return [Nfe::AddressLookupResponse]
      def search(filter: nil)
        query = {} #: Hash[String, untyped]
        query["$filter"] = filter unless filter.nil?
        response = get("/addresses", query: query)
        hydrate(Nfe::AddressLookupResponse, parse_json(response.body))
      end

      # Look up addresses by a free-text term.
      #
      # @param term [String] a non-empty search term.
      # @return [Nfe::AddressLookupResponse]
      # @raise [Nfe::InvalidRequestError] when +term+ is empty/whitespace.
      def lookup_by_term(term)
        raise Nfe::InvalidRequestError, "termo (term) não pode ser vazio" if term.to_s.strip.empty?

        response = get("/addresses/#{CGI.escape(term.strip)}")
        hydrate(Nfe::AddressLookupResponse, parse_json(response.body))
      end

      protected

      def api_family
        :addresses
      end

      # This family's host already embeds the API version, so no version
      # segment is prefixed to the request path.
      def api_version
        ""
      end
    end
  end
end
