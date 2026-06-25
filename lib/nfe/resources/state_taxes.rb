# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/state_taxes/nfe_state_tax"

module Nfe
  module Resources
    # Company state-tax (Inscrição Estadual) registrations for the +:cte+ host
    # family (+https://api.nfse.io/v2/companies/{companyId}/statetaxes+). Exposes
    # the full CRUD: list (cursor-style), create, retrieve, update and delete.
    #
    # The API wraps single state-tax objects in a +{"stateTax" => <object>}+
    # envelope (and the list in +{"stateTaxes" => [...]}+), transparently
    # unwrapped here before hydrating {Nfe::NfeStateTax}.
    #
    # @example
    #   client.state_taxes.create(company_id, code: "SP", taxNumber: "1234567890")
    #   client.state_taxes.list(company_id, limit: 50)
    class StateTaxes < AbstractResource
      # Envelope key for a single state-tax object.
      ENVELOPE = "stateTax"
      # Wrapper key for the list envelope.
      LIST_ENVELOPE = "stateTaxes"

      protected

      def api_family
        :cte
      end

      # The +:cte+ host (+api.nfse.io+) does not bake in a version; the +/v2+
      # segment is carried in the base path instead.
      def api_version
        ""
      end

      public

      # List a company's state-tax registrations (cursor-style pagination).
      #
      # @param company_id [String]
      # @param starting_after [String, nil] cursor — items after this id.
      # @param ending_before [String, nil] cursor — items before this id.
      # @param limit [Integer, nil] page size.
      # @return [Nfe::ListResponse]
      def list(company_id, starting_after: nil, ending_before: nil, limit: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        query = {} #: Hash[String, untyped]
        query["startingAfter"] = starting_after unless starting_after.nil?
        query["endingBefore"] = ending_before unless ending_before.nil?
        query["limit"] = limit unless limit.nil?
        response = get(base_path(cid), query: query)
        hydrate_list(Nfe::NfeStateTax, parse_json(response.body), wrapper_key: LIST_ENVELOPE)
      end

      # Create a state-tax registration.
      #
      # @param company_id [String]
      # @param data [Hash] state-tax attributes (camelCase keys per the API).
      # @return [Nfe::NfeStateTax]
      def create(company_id, data)
        cid = Nfe::IdValidator.company_id(company_id)
        response = post(base_path(cid), body: JSON.generate({ ENVELOPE => data }),
                                        headers: json_headers)
        hydrate(Nfe::NfeStateTax, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Retrieve a single state-tax registration.
      #
      # @param company_id [String]
      # @param state_tax_id [String]
      # @return [Nfe::NfeStateTax]
      def retrieve(company_id, state_tax_id)
        cid = Nfe::IdValidator.company_id(company_id)
        sid = Nfe::IdValidator.state_tax_id(state_tax_id)
        response = get("#{base_path(cid)}/#{sid}")
        hydrate(Nfe::NfeStateTax, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Update a state-tax registration.
      #
      # @param company_id [String]
      # @param state_tax_id [String]
      # @param data [Hash] state-tax attributes (camelCase keys per the API).
      # @return [Nfe::NfeStateTax]
      def update(company_id, state_tax_id, data)
        cid = Nfe::IdValidator.company_id(company_id)
        sid = Nfe::IdValidator.state_tax_id(state_tax_id)
        response = put("#{base_path(cid)}/#{sid}", body: JSON.generate({ ENVELOPE => data }),
                                                   headers: json_headers)
        hydrate(Nfe::NfeStateTax, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Delete a state-tax registration.
      #
      # @param company_id [String]
      # @param state_tax_id [String]
      # @return [nil]
      def delete(company_id, state_tax_id)
        cid = Nfe::IdValidator.company_id(company_id)
        sid = Nfe::IdValidator.state_tax_id(state_tax_id)
        super("#{base_path(cid)}/#{sid}")
        nil
      end

      private

      def base_path(company_id)
        "/v2/companies/#{company_id}/statetaxes"
      end

      def json_headers
        { "Content-Type" => "application/json" }
      end
    end
  end
end
