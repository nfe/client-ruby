# frozen_string_literal: true

RSpec.describe Nfe::WebhookSubscription do
  describe ".from_api" do
    it "maps camelCase keys onto snake_case members" do
      hook = described_class.from_api(
        "id" => "wh_1",
        "url" => "https://example.com/hook",
        "events" => ["invoice.issued"],
        "secret" => "s3cr3t",
        "active" => true,
        "status" => "Active",
        "createdOn" => "2026-01-01T00:00:00Z",
        "modifiedOn" => "2026-02-01T00:00:00Z"
      )

      expect(hook.id).to eq("wh_1")
      expect(hook.url).to eq("https://example.com/hook")
      expect(hook.events).to eq(["invoice.issued"])
      expect(hook.secret).to eq("s3cr3t")
      expect(hook.active).to be(true)
      expect(hook.status).to eq("Active")
      expect(hook.created_on).to eq("2026-01-01T00:00:00Z")
      expect(hook.modified_on).to eq("2026-02-01T00:00:00Z")
    end

    it "drops unknown keys and tolerates missing fields" do
      hook = described_class.from_api("id" => "wh_2", "mystery" => 1)
      expect(hook.id).to eq("wh_2")
      expect(hook.url).to be_nil
      expect(hook.events).to be_nil
    end

    it "returns nil for a nil payload" do
      expect(described_class.from_api(nil)).to be_nil
    end

    it "produces an immutable value object" do
      expect(described_class.from_api("id" => "wh_3")).to be_frozen
    end
  end
end
