# frozen_string_literal: true

require "nfe/resources/abstract_resource"
require "nfe/resources/dto/natural_person_lookup/natural_person_status_response"

module Nfe
  module Resources
    # Read-only lookups against the +naturalperson+ data API
    # (+https://naturalperson.api.nfe.io+). The version segment is embedded in
    # the request path, so +api_version+ is +""+.
    class NaturalPersonLookup < AbstractResource
      # Fetch the registration status of a natural person (CPF) at the federal
      # tax authority. The CPF is normalized to 11 digits and the birth date to
      # +YYYY-MM-DD+ before the request is issued (fail-fast).
      #
      # @param federal_tax_number [String] the CPF (with or without separators).
      # @param birth_date [String, Date, Time, DateTime] the person's birth date.
      # @return [Nfe::NaturalPersonStatusResponse, nil]
      def get_status(federal_tax_number, birth_date)
        cpf = Nfe::IdValidator.cpf(federal_tax_number)
        date = Nfe::DateNormalizer.to_iso_date(birth_date)
        response = get("/v1/naturalperson/status/#{cpf}/#{date}")
        hydrate(Nfe::NaturalPersonStatusResponse, parse_json(response.body))
      end

      protected

      def api_family = :natural_person

      # This family's host embeds the version in the path, so no version segment
      # is prefixed to the request path.
      def api_version = ""
    end
  end
end
