# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/webhook"
require "nfe/webhook"

module Nfe
  module Resources
    # Webhooks resource, company-scoped under +/companies/{id}/webhooks+ on the
    # +:main+ host family. Exposes CRUD, a synthetic-delivery +test+, the static
    # list of available events, and a thin {#verify_signature} delegation to
    # {Nfe::Webhook} (the canonical signature-verification API is the module).
    class Webhooks < AbstractResource
      # The seven event types the NFE.io API can deliver (parity with Node).
      AVAILABLE_EVENTS = %w[
        invoice.issued
        invoice.cancelled
        invoice.failed
        invoice.processing
        company.created
        company.updated
        company.deleted
      ].freeze

      protected

      def api_family
        :main
      end

      public

      # List a company's webhook subscriptions.
      #
      # @param company_id [String]
      # @return [Nfe::ListResponse]
      def list(company_id)
        id = Nfe::IdValidator.company_id(company_id)
        response = get("/companies/#{id}/webhooks")
        payload = parse_json(response.body)
        items = webhook_items(payload).map { |item| hydrate(Nfe::WebhookSubscription, item) }
        Nfe::ListResponse.new(data: items)
      end

      # Create a webhook subscription. Accepts +url+, +events+, +secret+, +active+.
      #
      # @param company_id [String]
      # @param data [Hash]
      # @return [Nfe::Webhook]
      def create(company_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        response = post("/companies/#{id}/webhooks",
                        body: json_body(data), headers: json_headers)
        hydrate(Nfe::WebhookSubscription, parse_json(response.body))
      end

      # Retrieve a webhook by id.
      #
      # @param company_id [String]
      # @param webhook_id [String]
      # @return [Nfe::Webhook]
      def retrieve(company_id, webhook_id)
        id = Nfe::IdValidator.company_id(company_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        response = get("/companies/#{id}/webhooks/#{wid}")
        hydrate(Nfe::WebhookSubscription, parse_json(response.body))
      end

      # Update a webhook.
      #
      # @param company_id [String]
      # @param webhook_id [String]
      # @param data [Hash]
      # @return [Nfe::Webhook]
      def update(company_id, webhook_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        response = put("/companies/#{id}/webhooks/#{wid}",
                       body: json_body(data), headers: json_headers)
        hydrate(Nfe::WebhookSubscription, parse_json(response.body))
      end

      # Delete a webhook.
      #
      # @param company_id [String]
      # @param webhook_id [String]
      # @return [nil]
      def delete(company_id, webhook_id)
        id = Nfe::IdValidator.company_id(company_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        super("/companies/#{id}/webhooks/#{wid}")
        nil
      end

      # Trigger a synthetic delivery to verify a webhook is reachable.
      #
      # @param company_id [String]
      # @param webhook_id [String]
      # @return [Hash] +{ success: bool, message: String? }+.
      def test(company_id, webhook_id)
        id = Nfe::IdValidator.company_id(company_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        response = post("/companies/#{id}/webhooks/#{wid}/test",
                        body: json_body({}), headers: json_headers)
        payload = parse_json(response.body) || {}
        { success: payload["success"] || false, message: payload["message"] }
      end

      # The static list of webhook event types the API can deliver.
      #
      # @return [Array<String>]
      def get_available_events
        AVAILABLE_EVENTS.dup
      end

      # Verify a webhook signature. Thin delegation to {Nfe::Webhook} for Node
      # parity; the canonical API is the module. Never raises.
      #
      # @return [Boolean]
      def verify_signature(payload:, signature:, secret:)
        Nfe::Webhook.verify_signature(payload: payload, signature: signature, secret: secret)
      end

      private

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end

      # Tolerate either a bare array, a +data+-wrapped list, or a +webhooks+
      # envelope for the list response.
      def webhook_items(payload)
        return payload if payload.is_a?(Array)
        return [] unless payload.is_a?(Hash)

        payload["data"] || payload["webhooks"] || payload[:data] || payload[:webhooks] || []
      end
    end
  end
end
