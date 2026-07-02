# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/natural_person"

module Nfe
  module Resources
    # Natural-people (pessoas físicas) resource, scoped by company under
    # +/companies/{id}/naturalpeople+ on the +:main+ host family. The API wraps
    # responses in a +{"naturalPeople" => ...}+ envelope, unwrapped here before
    # hydrating {Nfe::NaturalPerson}.
    class NaturalPeople < AbstractResource
      ENVELOPE = "naturalPeople"

      protected

      def api_family
        :main
      end

      public

      # List every natural person for a company (no pagination, parity with Node).
      #
      # @param company_id [String]
      # @return [Nfe::ListResponse]
      def list(company_id)
        id = Nfe::IdValidator.company_id(company_id)
        response = get("/companies/#{id}/naturalpeople")
        items = (unwrap(parse_json(response.body), ENVELOPE) || [])
                .map { |item| hydrate(Nfe::NaturalPerson, item) }
        Nfe::ListResponse.new(data: items)
      end

      # Create a natural person.
      #
      # @param company_id [String]
      # @param data [Hash]
      # @return [Nfe::NaturalPerson]
      def create(company_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        response = post("/companies/#{id}/naturalpeople",
                        body: json_body(data), headers: json_headers)
        hydrate(Nfe::NaturalPerson, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Retrieve a natural person by id.
      #
      # @param company_id [String]
      # @param natural_person_id [String]
      # @return [Nfe::NaturalPerson]
      def retrieve(company_id, natural_person_id)
        id = Nfe::IdValidator.company_id(company_id)
        npid = Nfe::IdValidator.presence!(natural_person_id, "natural_person_id")
        response = get("/companies/#{id}/naturalpeople/#{npid}")
        hydrate(Nfe::NaturalPerson, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Update a natural person.
      #
      # @param company_id [String]
      # @param natural_person_id [String]
      # @param data [Hash]
      # @return [Nfe::NaturalPerson]
      def update(company_id, natural_person_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        npid = Nfe::IdValidator.presence!(natural_person_id, "natural_person_id")
        response = put("/companies/#{id}/naturalpeople/#{npid}",
                       body: json_body(data), headers: json_headers)
        hydrate(Nfe::NaturalPerson, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Delete a natural person.
      #
      # @param company_id [String]
      # @param natural_person_id [String]
      # @return [nil]
      def delete(company_id, natural_person_id)
        id = Nfe::IdValidator.company_id(company_id)
        npid = Nfe::IdValidator.presence!(natural_person_id, "natural_person_id")
        super("/companies/#{id}/naturalpeople/#{npid}")
        nil
      end

      # Create several natural people. Unlike the Node SDK (+Promise.all+), this
      # runs the +create+ calls sequentially and returns them in order.
      #
      # @param company_id [String]
      # @param list [Array<Hash>]
      # @return [Array<Nfe::NaturalPerson>]
      def create_batch(company_id, list)
        list.map { |data| create(company_id, data) }
      end

      # Find a natural person by federal tax number (CPF). Normalises the input
      # to 11 digits before filtering. Convenience helper built on {#list}.
      #
      # @param company_id [String]
      # @param federal_tax_number [String]
      # @return [Nfe::NaturalPerson, nil]
      def find_by_tax_number(company_id, federal_tax_number)
        target = federal_tax_number.to_s.gsub(/\D/, "")
        list(company_id).data.find do |person|
          person.federal_tax_number.to_s.gsub(/\D/, "") == target
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
