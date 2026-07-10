# frozen_string_literal: true

RSpec.describe Nfe::AccountWebhook do
  describe ".from_api" do
    let(:hook) do
      described_class.from_api(
        "id" => "5f3a0b1c-2d4e-4f6a-8b9c-0d1e2f3a4b5c",
        "uri" => "https://example.com/hook",
        "contentType" => "json",
        "secret" => "0123456789abcdef0123456789abcdef",
        "filters" => ["service_invoice.issued_successfully"],
        "insecureSsl" => false,
        "headers" => { "X-Custom" => "1" },
        "properties" => { "env" => "prod" },
        "status" => "Active",
        "createdOn" => "2026-07-02T18:00:00Z",
        "modifiedOn" => "2026-07-03T09:00:00Z"
      )
    end

    it "maps the identity and delivery fields" do
      expect(hook.id).to eq("5f3a0b1c-2d4e-4f6a-8b9c-0d1e2f3a4b5c")
      expect(hook.uri).to eq("https://example.com/hook")
      expect(hook.content_type).to eq("json")
      expect(hook.secret).to eq("0123456789abcdef0123456789abcdef")
      expect(hook.filters).to eq(["service_invoice.issued_successfully"])
      expect(hook.insecure_ssl).to be(false)
    end

    it "maps the metadata and audit fields" do
      expect(hook.headers).to eq({ "X-Custom" => "1" })
      expect(hook.properties).to eq({ "env" => "prod" })
      expect(hook.status).to eq("Active")
      expect(hook.created_on).to eq("2026-07-02T18:00:00Z")
      expect(hook.modified_on).to eq("2026-07-03T09:00:00Z")
    end

    it "drops unknown keys and tolerates missing fields (secret omitted on reads)" do
      hook = described_class.from_api("id" => "wh_2", "mystery" => 1)
      expect(hook.id).to eq("wh_2")
      expect(hook.uri).to be_nil
      expect(hook.secret).to be_nil
    end

    it "returns nil for a nil payload" do
      expect(described_class.from_api(nil)).to be_nil
    end

    it "produces an immutable value object" do
      expect(described_class.from_api("id" => "wh_3")).to be_frozen
    end
  end
end
