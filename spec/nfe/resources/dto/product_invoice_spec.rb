# frozen_string_literal: true

RSpec.describe Nfe::ProductInvoice do
  describe ".from_api" do
    let(:payload) do
      {
        "id" => "pi_1",
        "flowStatus" => "Issued",
        "flowMessage" => "ok",
        "status" => "Authorized",
        "environment" => "Production",
        "serie" => 1,
        "number" => 200,
        "operationNature" => "Venda",
        "operationType" => "Outgoing",
        "accessKey" => "0" * 44,
        "protocol" => "PROTO",
        "items" => [{ "code" => "P1" }],
        "totals" => { "amount" => 100 },
        "issuedOn" => "2026-01-01T00:00:00Z"
      }
    end

    it "maps camelCase keys onto snake_case members" do
      invoice = described_class.from_api(payload)

      expect(invoice.id).to eq("pi_1")
      expect(invoice.flow_status).to eq("Issued")
      expect(invoice.operation_nature).to eq("Venda")
      expect(invoice.operation_type).to eq("Outgoing")
      expect(invoice.access_key).to eq("0" * 44)
      expect(invoice.items).to eq([{ "code" => "P1" }])
    end

    it "drops unknown keys and tolerates missing fields" do
      invoice = described_class.from_api("id" => "pi_2", "weird" => 1)
      expect(invoice.id).to eq("pi_2")
      expect(invoice.flow_status).to be_nil
      expect(invoice).not_to respond_to(:weird)
    end

    it "returns nil for a nil payload" do
      expect(described_class.from_api(nil)).to be_nil
    end
  end
end
