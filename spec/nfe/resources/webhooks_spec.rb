# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::Webhooks do
  subject(:webhooks) { client.webhooks }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def json(status: 200, body: "{}")
    Nfe::Http::Response.new(status: status, body: body)
  end

  def last_request
    transport.requests.last
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
