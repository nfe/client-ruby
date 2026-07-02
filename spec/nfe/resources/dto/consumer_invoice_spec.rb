# frozen_string_literal: true

RSpec.describe Nfe::ConsumerInvoice do
  describe ".from_api" do
    let(:payload) do
      {
        "id" => "nfc_1",
        "status" => "Issued",
        "flowStatus" => "Issued",
        "flowMessage" => "Autorizada",
        "environment" => "Production",
        "accessKey" => "3524011234567800019059000000001234567890",
        "number" => 12,
        "serie" => 1,
        "totalAmount" => 99.9,
        "issuedOn" => "2026-01-01T00:00:00Z",
        "createdOn" => "2026-01-01T00:00:00Z",
        "modifiedOn" => "2026-01-02T00:00:00Z",
        "cancelledOn" => nil
      }
    end

    it "maps camelCase keys onto snake_case members" do
      invoice = described_class.from_api(payload)

      expect(invoice.id).to eq("nfc_1")
      expect(invoice.flow_status).to eq("Issued")
      expect(invoice.flow_message).to eq("Autorizada")
      expect(invoice.environment).to eq("Production")
      expect(invoice.access_key).to eq("3524011234567800019059000000001234567890")
      expect(invoice.number).to eq(12)
      expect(invoice.serie).to eq(1)
      expect(invoice.total_amount).to eq(99.9)
      expect(invoice.issued_on).to eq("2026-01-01T00:00:00Z")
      expect(invoice.modified_on).to eq("2026-01-02T00:00:00Z")
    end

    it "preserves the raw payload for forward compatibility" do
      payload = { "id" => "nfc_2", "newApiField" => "kept" }
      invoice = described_class.from_api(payload)

      expect(invoice.raw).to eq(payload)
      expect(invoice).not_to respond_to(:new_api_field)
    end

    it "tolerates missing fields" do
      invoice = described_class.from_api("id" => "nfc_3")
      expect(invoice.id).to eq("nfc_3")
      expect(invoice.flow_status).to be_nil
      expect(invoice.total_amount).to be_nil
    end

    it "returns nil for a nil payload" do
      expect(described_class.from_api(nil)).to be_nil
    end

    it "produces an immutable value object" do
      expect(described_class.from_api("id" => "nfc_4")).to be_frozen
    end
  end
end
