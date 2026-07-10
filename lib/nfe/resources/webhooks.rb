# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/account_webhook"
require "nfe/resources/dto/webhook"
require "nfe/webhook"

module Nfe
  module Resources
    # Webhooks resource on the +:main+ host family.
    #
    # Webhooks are managed at the **account** level over +/v2/webhooks+ — use
    # the +*_account_webhook*+ methods. The live API wraps create/update
    # requests and single-object responses in a +webHook+ envelope; the SDK
    # envelopes/unwraps transparently. Contract source of truth:
    # +openapi/nf-servico-v1.yaml+ plus live probes (2026-07-02/03).
    #
    # The company-scoped methods (+list+/+create+/+retrieve+/+update+/
    # +delete+/+test+ under +/v1/companies/{id}/webhooks+) are deprecated: the
    # route returns 404 on the current API (confirmed on three accounts,
    # 2026-07-02/03). They remain, unchanged, until the next major.
    #
    # Also exposes a thin {#verify_signature} delegation to {Nfe::Webhook}
    # (the canonical signature-verification API is the module).
    class Webhooks < AbstractResource
      # Preserve the inherited HTTP DELETE helper under a private name before
      # the public company-scoped +delete+ shadows it — the account-scoped
      # deletes still need the raw verb.
      alias http_delete delete
      private :http_delete

      # Legacy static list of event types.
      #
      # @deprecated These literals do not exist on the live API — the real
      #   event types follow +service_invoice.*+/+product_invoice.*+/
      #   +consumer_invoice.*+ (46 ids live). Use {#fetch_event_types}.
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

      # Account-scoped endpoints live under +/v2+ on the same +:main+ host,
      # while the (deprecated) company-scoped ones keep the resource default
      # +/v1+. A path that already carries an explicit version segment passes
      # through unprefixed.
      def full_path(path)
        path.start_with?("/v2/") ? path : super
      end

      public

      # List the account's webhooks (+GET /v2/webhooks+).
      #
      # The API wraps the collection as +{"webHooks": [...]}+; the SDK unwraps
      # it into an {Nfe::ListResponse} of {Nfe::AccountWebhook}. +secret+ is
      # omitted on reads.
      #
      # @return [Nfe::ListResponse]
      def list_account_webhooks
        response = get("/v2/webhooks")
        hydrate_list(Nfe::AccountWebhook, parse_json(response.body), wrapper_key: "webHooks")
      end

      # Create an account webhook (+POST /v2/webhooks+).
      #
      # The request is wrapped in the mandatory +webHook+ envelope (the API
      # rejects a bare body with +400 "missing required properties: 'webHook'"+)
      # and the +201 {"webHook": {...}}+ response is unwrapped.
      #
      # NFE.io **pings the +uri+ at creation time and requires a 2xx
      # response** — the endpoint must already be live, or the create fails.
      # +secret+ must be 32–64 characters; it is echoed back on create and
      # omitted on subsequent reads.
      #
      # @param data [Hash] webhook attributes in wire (camelCase) keys, e.g.
      #   +{ uri: "https://...", contentType: "json", secret: "<32-64 chars>",
      #   filters: ["service_invoice.issued_successfully"], status: "Active" }+.
      #   Discover valid +filters+ with {#fetch_event_types}.
      # @return [Nfe::AccountWebhook]
      def create_account_webhook(data)
        response = post("/v2/webhooks",
                        body: json_body({ webHook: data }), headers: json_headers)
        hydrate_account_webhook(response)
      end

      # Retrieve an account webhook by id (+GET /v2/webhooks/{id}+).
      #
      # Unwraps the +{"webHook": {...}}+ envelope, falling back to the raw
      # body when the envelope is absent. +secret+ is omitted on reads.
      #
      # @param webhook_id [String]
      # @return [Nfe::AccountWebhook]
      def retrieve_account_webhook(webhook_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        response = get("/v2/webhooks/#{wid}")
        hydrate_account_webhook(response)
      end

      # Update an account webhook (+PUT /v2/webhooks/{id}+), request wrapped
      # in the +webHook+ envelope.
      #
      # @note **+PUT+ is a full replacement** (live-confirmed 2026-07-03):
      #   omitted fields reset to their defaults — an update without +status+
      #   **deactivates the webhook**. Always send the complete object,
      #   starting from a retrieve:
      #
      #     current = client.webhooks.retrieve_account_webhook(id)
      #     client.webhooks.update_account_webhook(id, {
      #       uri: current.uri,
      #       contentType: current.content_type,
      #       status: current.status,            # keep it "Active"!
      #       filters: ["service_invoice.issued_successfully"]
      #     })
      #
      # @param webhook_id [String]
      # @param data [Hash] the complete webhook attributes (wire camelCase keys).
      # @return [Nfe::AccountWebhook]
      def update_account_webhook(webhook_id, data)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        response = put("/v2/webhooks/#{wid}",
                       body: json_body({ webHook: data }), headers: json_headers)
        hydrate_account_webhook(response)
      end

      # Delete a single account webhook by id (+DELETE /v2/webhooks/{id}+).
      #
      # @param webhook_id [String]
      # @return [nil]
      def delete_account_webhook(webhook_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        http_delete("/v2/webhooks/#{wid}")
        nil
      end

      # ⚠️ DESTRUCTIVE: delete **ALL** of the account's webhooks
      # (+DELETE /v2/webhooks+). Named distinctly from
      # {#delete_account_webhook} so it can never be reached by a mistyped
      # single delete.
      #
      # @return [nil]
      def delete_all_account_webhooks
        http_delete("/v2/webhooks")
        nil
      end

      # Trigger a test ping for an account webhook
      # (+PUT /v2/webhooks/{id}/pings+, responds 204).
      #
      # @param webhook_id [String]
      # @return [nil]
      def ping_account_webhook(webhook_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        put("/v2/webhooks/#{wid}/pings", body: json_body({}), headers: json_headers)
        nil
      end

      # Fetch the live list of webhook event types
      # (+GET /v2/webhooks/eventTypes+).
      #
      # The API wraps the result as +{"eventTypes": [{ "id": ... }, ...]}+;
      # this extracts the ids (e.g. +"service_invoice.issued_successfully"+,
      # +"product_invoice.issued"+ — 46 ids live). Use these as +filters+ when
      # creating or updating a webhook.
      #
      # @return [Array<String>]
      def fetch_event_types
        response = get("/v2/webhooks/eventTypes")
        payload = parse_json(response.body)
        items = [] #: Array[untyped]
        items = payload["eventTypes"] || items if payload.is_a?(Hash)
        items.map { |item| item["id"] }.compact
      end

      # List a company's webhook subscriptions.
      #
      # @deprecated The +/v1/companies/{id}/webhooks+ route returns 404 on the
      #   current API (confirmed on three accounts, 2026-07-02/03). Use
      #   {#list_account_webhooks}.
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
      # @deprecated The +/v1/companies/{id}/webhooks+ route returns 404 on the
      #   current API (confirmed on three accounts, 2026-07-02/03). Use
      #   {#create_account_webhook}.
      #
      # @param company_id [String]
      # @param data [Hash]
      # @return [Nfe::WebhookSubscription, nil]
      def create(company_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        response = post("/companies/#{id}/webhooks",
                        body: json_body(data), headers: json_headers)
        hydrate(Nfe::WebhookSubscription, parse_json(response.body))
      end

      # Retrieve a webhook by id.
      #
      # @deprecated The +/v1/companies/{id}/webhooks+ route returns 404 on the
      #   current API (confirmed on three accounts, 2026-07-02/03). Use
      #   {#retrieve_account_webhook}.
      #
      # @param company_id [String]
      # @param webhook_id [String]
      # @return [Nfe::WebhookSubscription, nil]
      def retrieve(company_id, webhook_id)
        id = Nfe::IdValidator.company_id(company_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        response = get("/companies/#{id}/webhooks/#{wid}")
        hydrate(Nfe::WebhookSubscription, parse_json(response.body))
      end

      # Update a webhook.
      #
      # @deprecated The +/v1/companies/{id}/webhooks+ route returns 404 on the
      #   current API (confirmed on three accounts, 2026-07-02/03). Use
      #   {#update_account_webhook}.
      #
      # @param company_id [String]
      # @param webhook_id [String]
      # @param data [Hash]
      # @return [Nfe::WebhookSubscription, nil]
      def update(company_id, webhook_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        wid = Nfe::IdValidator.presence!(webhook_id, "webhook_id")
        response = put("/companies/#{id}/webhooks/#{wid}",
                       body: json_body(data), headers: json_headers)
        hydrate(Nfe::WebhookSubscription, parse_json(response.body))
      end

      # Delete a webhook.
      #
      # @deprecated The +/v1/companies/{id}/webhooks+ route returns 404 on the
      #   current API (confirmed on three accounts, 2026-07-02/03). Use
      #   {#delete_account_webhook}.
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
      # @deprecated The +/v1/companies/{id}/webhooks+ route returns 404 on the
      #   current API (confirmed on three accounts, 2026-07-02/03). Use
      #   {#ping_account_webhook}.
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

      # The legacy static list of webhook event types.
      #
      # @deprecated These literals do not exist on the live API. Use
      #   {#fetch_event_types} for the real, live list.
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

      # Unwrap a single-object +{"webHook": {...}}+ envelope (raw-body
      # fallback) and hydrate an {Nfe::AccountWebhook}.
      def hydrate_account_webhook(response)
        hydrate(Nfe::AccountWebhook, unwrap(parse_json(response.body), "webHook"))
      end

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end

      # Tolerate either a bare array, a +data+-wrapped list, or a +webhooks+
      # envelope for the (deprecated) company-scoped list response.
      def webhook_items(payload)
        return payload if payload.is_a?(Array)
        return [] unless payload.is_a?(Hash)

        payload["data"] || payload["webhooks"] || payload[:data] || payload[:webhooks] || []
      end
    end
  end
end
