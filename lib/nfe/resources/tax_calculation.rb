# frozen_string_literal: true

require "cgi"
require "json"
require "nfe/resources/abstract_resource"
require "nfe/generated/calculo_impostos_v1/cofins"
require "nfe/generated/calculo_impostos_v1/icms"
require "nfe/generated/calculo_impostos_v1/icms_uf_dest"
require "nfe/generated/calculo_impostos_v1/ii"
require "nfe/generated/calculo_impostos_v1/ipi"
require "nfe/generated/calculo_impostos_v1/pis"
require "nfe/generated/calculo_impostos_v1/calculate_item_response"
require "nfe/generated/calculo_impostos_v1/calculate_response"

module Nfe
  module Resources
    # Tax calculation engine for the +:cte+ family (host +api.nfse.io+). Runs the
    # tax rules engine for a tenant and returns a per-item tax breakdown.
    class TaxCalculation < AbstractResource
      protected

      def api_family = :cte

      # The path already carries its own segments, so no version prefix is added.
      def api_version = ""

      public

      # Run the tax-rules engine for +tenant_id+ over +request+.
      #
      # Client-side validation runs FIRST (no HTTP when invalid): +tenant_id+
      # must be non-empty and +request+ must be a Hash carrying +operation_type+
      # (or +operationType+) plus a non-empty +items+ Array.
      #
      # +request+ accepts a plain Hash. For type-safety you may build it from
      # {Nfe::Generated::CalculoImpostosV1::CalculateRequest#to_h}.
      #
      # @param tenant_id [String] the tenant identifier (URL-encoded into the path).
      # @param request [Hash] the calculation request body.
      # @return [Nfe::Generated::CalculoImpostosV1::CalculateResponse]
      def calculate(tenant_id, request)
        validate_calculate!(tenant_id, request)
        path = "/tax-rules/#{CGI.escape(tenant_id.to_s.strip)}/engine/calculate"
        response = post(path, body: JSON.generate(request),
                              headers: { "Content-Type" => "application/json" })
        hydrate(Nfe::Generated::CalculoImpostosV1::CalculateResponse, parse_json(response.body))
      end

      private

      # Fail fast (no HTTP) when the tenant or request shape is invalid.
      def validate_calculate!(tenant_id, request)
        Nfe::IdValidator.presence!(tenant_id, "tenant_id")
        return if request.is_a?(Hash) && operation_type?(request) && items?(request)

        raise Nfe::InvalidRequestError,
              "request deve conter operation_type (ou operationType) e items (Array não vazio)"
      end

      def operation_type?(request)
        !request[:operation_type].nil? || !request["operation_type"].nil? ||
          !request[:operationType].nil? || !request["operationType"].nil?
      end

      def items?(request)
        items = request[:items] || request["items"]
        items.is_a?(Array) && !items.empty?
      end
    end
  end
end
