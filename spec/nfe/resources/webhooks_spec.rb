# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::Webhooks do
  subject(:webhooks) { client.webhooks }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }

  # Wire fixture taken from the live probe transcript (2026-07-02/03): the API
  # envelopes single objects as {"webHook": {...}} and serializes
  # contentType/status as strings ("json", "Active").
  let(:wire_webhook) do
    {
      "id" => "5f3a0b1c-2d4e-4f6a-8b9c-0d1e2f3a4b5c",
      "uri" => "https://example.com/hook",
      "contentType" => "json",
      "secret" => "0123456789abcdef0123456789abcdef",
      "insecureSsl" => false,
      "status" => "Active",
      "filters" => ["service_invoice.issued_successfully"],
      "createdOn" => "2026-07-02T18:00:00Z",
      "modifiedOn" => "2026-07-02T18:00:00Z"
    }
  end

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def json(status: 200, body: "{}")
    Nfe::Http::Response.new(status: status, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "#create_account_webhook" do
    it "POSTs /v2/webhooks with the webHook envelope and unwraps the 201" do
      transport.enqueue(json(status: 201, body: { "webHook" => wire_webhook }.to_json))

      hook = webhooks.create_account_webhook(
        uri: "https://example.com/hook",
        contentType: "json",
        secret: "0123456789abcdef0123456789abcdef",
        filters: ["service_invoice.issued_successfully"]
      )

      expect(last_request.method).to eq("POST")
      expect(last_request.url).to eq("https://api.nfe.io/v2/webhooks")
      sent = JSON.parse(last_request.body)
      expect(sent.keys).to eq(["webHook"])
      expect(sent["webHook"]["uri"]).to eq("https://example.com/hook")

      expect(hook).to be_a(Nfe::AccountWebhook)
      expect(hook.id).to eq("5f3a0b1c-2d4e-4f6a-8b9c-0d1e2f3a4b5c")
      expect(hook.content_type).to eq("json")
      expect(hook.secret).to eq("0123456789abcdef0123456789abcdef")
      expect(hook.status).to eq("Active")
    end
  end

  describe "#retrieve_account_webhook" do
    it "GETs /v2/webhooks/{id} and unwraps the webHook envelope" do
      transport.enqueue(json(body: { "webHook" => wire_webhook }.to_json))

      hook = webhooks.retrieve_account_webhook("wh-1")

      expect(last_request.url).to eq("https://api.nfe.io/v2/webhooks/wh-1")
      expect(hook.uri).to eq("https://example.com/hook")
      expect(hook.filters).to eq(["service_invoice.issued_successfully"])
    end

    it "falls back to a raw (unenveloped) body" do
      transport.enqueue(json(body: wire_webhook.to_json))

      hook = webhooks.retrieve_account_webhook("wh-1")

      expect(hook).to be_a(Nfe::AccountWebhook)
      expect(hook.id).to eq("5f3a0b1c-2d4e-4f6a-8b9c-0d1e2f3a4b5c")
    end

    it "rejects an empty webhook_id without HTTP" do
      expect { webhooks.retrieve_account_webhook("") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#update_account_webhook" do
    it "PUTs the webHook envelope and unwraps the response" do
      transport.enqueue(json(body: { "webHook" => wire_webhook.merge("status" => "Inactive") }.to_json))

      hook = webhooks.update_account_webhook("wh-1", uri: "https://example.com/hook")

      expect(last_request.method).to eq("PUT")
      expect(last_request.url).to eq("https://api.nfe.io/v2/webhooks/wh-1")
      expect(JSON.parse(last_request.body).keys).to eq(["webHook"])
      expect(hook.status).to eq("Inactive")
    end
  end

  describe "#list_account_webhooks" do
    it "GETs /v2/webhooks and unwraps the webHooks envelope into a ListResponse" do
      transport.enqueue(json(body: { "webHooks" => [wire_webhook] }.to_json))

      result = webhooks.list_account_webhooks

      expect(last_request.url).to eq("https://api.nfe.io/v2/webhooks")
      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.first).to be_a(Nfe::AccountWebhook)
      expect(result.data.first.uri).to eq("https://example.com/hook")
    end
  end

  describe "#delete_account_webhook / #delete_all_account_webhooks" do
    it "DELETEs a single webhook by id and returns nil" do
      transport.enqueue(json(status: 204, body: ""))

      expect(webhooks.delete_account_webhook("wh-1")).to be_nil
      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to eq("https://api.nfe.io/v2/webhooks/wh-1")
    end

    it "exposes the destructive bulk delete as a distinct zero-arg method" do
      transport.enqueue(json(status: 204, body: ""))

      expect(webhooks.method(:delete_all_account_webhooks).arity).to eq(0)
      expect(webhooks.delete_all_account_webhooks).to be_nil
      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to eq("https://api.nfe.io/v2/webhooks")
    end

    it "keeps the single delete unreachable without an id" do
      expect { webhooks.delete_account_webhook("") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#ping_account_webhook" do
    it "PUTs /v2/webhooks/{id}/pings and returns nil" do
      transport.enqueue(json(status: 204, body: ""))

      expect(webhooks.ping_account_webhook("wh-1")).to be_nil
      expect(last_request.method).to eq("PUT")
      expect(last_request.url).to eq("https://api.nfe.io/v2/webhooks/wh-1/pings")
    end
  end

  describe "#fetch_event_types" do
    it "GETs /v2/webhooks/eventTypes and extracts the ids" do
      transport.enqueue(json(body: {
        "eventTypes" => [
          { "id" => "service_invoice.issued_successfully", "description" => "..." },
          { "id" => "product_invoice.issued" }
        ]
      }.to_json))

      events = webhooks.fetch_event_types

      expect(last_request.url).to eq("https://api.nfe.io/v2/webhooks/eventTypes")
      expect(events).to eq(%w[service_invoice.issued_successfully product_invoice.issued])
    end

    it "returns an empty array for an empty body" do
      transport.enqueue(json(body: ""))
      expect(webhooks.fetch_event_types).to eq([])
    end
  end

  describe "#list" do
    it "lists company-scoped webhooks" do
      transport.enqueue(json(body: { "data" => [{ "id" => "wh1" }] }.to_json))

      result = webhooks.list("co-1")

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.first).to be_a(Nfe::WebhookSubscription)
      expect(result.data.first.id).to eq("wh1")
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co-1/webhooks")
    end

    it "rejects an empty company_id without HTTP" do
      expect { webhooks.list("") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#create" do
    it "POSTs and hydrates a WebhookSubscription" do
      transport.enqueue(json(body: {
        "id" => "wh1", "url" => "https://example.com/hook",
        "events" => ["invoice.issued"], "secret" => "s3cr3t"
      }.to_json))

      webhook = webhooks.create("co-1", url: "https://example.com/hook", events: ["invoice.issued"])

      expect(webhook.id).to eq("wh1")
      expect(webhook.url).to eq("https://example.com/hook")
      expect(webhook.events).to eq(["invoice.issued"])
      expect(webhook.secret).to eq("s3cr3t")
      expect(last_request.method).to eq("POST")
    end
  end

  describe "#retrieve / #update / #delete" do
    it "retrieves by id" do
      transport.enqueue(json(body: { "id" => "wh1" }.to_json))
      expect(webhooks.retrieve("co-1", "wh1").id).to eq("wh1")
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co-1/webhooks/wh1")
    end

    it "updates by id" do
      transport.enqueue(json(body: { "id" => "wh1", "active" => false }.to_json))
      expect(webhooks.update("co-1", "wh1", active: false).active).to be(false)
      expect(last_request.method).to eq("PUT")
    end

    it "deletes and returns nil" do
      transport.enqueue(json(status: 200, body: ""))
      expect(webhooks.delete("co-1", "wh1")).to be_nil
      expect(last_request.method).to eq("DELETE")
    end
  end

  describe "#test" do
    it "POSTs to /test and returns success/message" do
      transport.enqueue(json(body: { "success" => true, "message" => "delivered" }.to_json))

      result = webhooks.test("co-1", "wh1")

      expect(result).to eq({ success: true, message: "delivered" })
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co-1/webhooks/wh1/test")
      expect(last_request.method).to eq("POST")
    end
  end

  describe "#get_available_events" do
    it "returns exactly the seven static events" do
      expect(webhooks.get_available_events).to eq(%w[
                                                    invoice.issued
                                                    invoice.cancelled
                                                    invoice.failed
                                                    invoice.processing
                                                    company.created
                                                    company.updated
                                                    company.deleted
                                                  ])
    end
  end

  describe "#verify_signature" do
    it "delegates to Nfe::Webhook.verify_signature" do
      allow(Nfe::Webhook).to receive(:verify_signature).and_return(true)

      result = webhooks.verify_signature(payload: "body", signature: "sha1=abc", secret: "s")

      expect(result).to be(true)
      expect(Nfe::Webhook).to have_received(:verify_signature)
        .with(payload: "body", signature: "sha1=abc", secret: "s")
    end
  end
end
