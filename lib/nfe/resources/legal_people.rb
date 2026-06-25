# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/legal_person"

module Nfe
  module Resources
    # Legal-people (pessoas jurídicas) resource, scoped by company under
    # +/companies/{id}/legalpeople+ on the +:main+ host family. The API wraps
    # responses in a +{"legalPeople" => ...}+ envelope, unwrapped here before
    # hydrating {Nfe::LegalPerson}.
    class LegalPeople < AbstractResource
      ENVELOPE = "legalPeople"

      protected

      def api_family
        :main
      end

      public

      # List every legal person for a company (no pagination, parity with Node).
      #
      # @param company_id [String]
      # @return [Nfe::ListResponse]
      def list(company_id)
        id = Nfe::IdValidator.company_id(company_id)
        response = get("/companies/#{id}/legalpeople")
        items = (unwrap(parse_json(response.body), ENVELOPE) || [])
                .map { |item| hydrate(Nfe::LegalPerson, item) }
        Nfe::ListResponse.new(data: items)
      end

      # Create a legal person.
      #
      # @param company_id [String]
      # @param data [Hash]
      # @return [Nfe::LegalPerson]
      def create(company_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        response = post("/companies/#{id}/legalpeople",
                        body: json_body(data), headers: json_headers)
        hydrate(Nfe::LegalPerson, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Retrieve a legal person by id.
      #
      # @param company_id [String]
      # @param legal_person_id [String]
      # @return [Nfe::LegalPerson]
      def retrieve(company_id, legal_person_id)
        id = Nfe::IdValidator.company_id(company_id)
        lpid = Nfe::IdValidator.presence!(legal_person_id, "legal_person_id")
        response = get("/companies/#{id}/legalpeople/#{lpid}")
        hydrate(Nfe::LegalPerson, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Update a legal person.
      #
      # @param company_id [String]
      # @param legal_person_id [String]
      # @param data [Hash]
      # @return [Nfe::LegalPerson]
      def update(company_id, legal_person_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        lpid = Nfe::IdValidator.presence!(legal_person_id, "legal_person_id")
        response = put("/companies/#{id}/legalpeople/#{lpid}",
                       body: json_body(data), headers: json_headers)
        hydrate(Nfe::LegalPerson, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Delete a legal person.
      #
      # @param company_id [String]
      # @param legal_person_id [String]
      # @return [nil]
      def delete(company_id, legal_person_id)
        id = Nfe::IdValidator.company_id(company_id)
        lpid = Nfe::IdValidator.presence!(legal_person_id, "legal_person_id")
        super("/companies/#{id}/legalpeople/#{lpid}")
        nil
      end

      # Create several legal people. Unlike the Node SDK (+Promise.all+), this
      # runs the +create+ calls sequentially and returns them in order.
      #
      # @param company_id [String]
      # @param list [Array<Hash>]
      # @return [Array<Nfe::LegalPerson>]
      def create_batch(company_id, list)
        list.map { |data| create(company_id, data) }
      end

      # Find a legal person by federal tax number (CNPJ). Convenience helper
      # built on {#list} plus client-side filtering.
      #
      # @param company_id [String]
      # @param federal_tax_number [String]
      # @return [Nfe::LegalPerson, nil]
      def find_by_tax_number(company_id, federal_tax_number)
        target = federal_tax_number.to_s.gsub(/[^0-9A-Za-z]/, "")
        list(company_id).data.find do |person|
          person.federal_tax_number.to_s.gsub(/[^0-9A-Za-z]/, "") == target
        end
      end

      private

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end
    end
  end
end
