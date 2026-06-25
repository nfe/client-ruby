# frozen_string_literal: true

RSpec.describe Nfe::ServiceInvoice do
  describe ".from_api" do
    let(:payload) do
      {
        "id" => "si_1",
        "flowStatus" => "Issued",
        "flowMessage" => "ok",
        "status" => "Done",
        "environment" => "Production",
        "rpsNumber" => 42,
        "rpsSerialNumber" => "A1",
        "number" => 100,
        "checkCode" => "ABC123",
        "issuedOn" => "2026-01-01T00:00:00Z",
        "servicesAmount" => 1000.0,
        "cityServiceCode" => "01234",
        "description" => "Serviço X",
        "createdOn" => "2026-01-01T00:00:00Z",
        "modifiedOn" => "2026-01-02T00:00:00Z"
      }
    end

    it "maps camelCase keys onto snake_case members" do
      invoice = described_class.from_api(payload)

      expect(invoice.id).to eq("si_1")
      expect(invoice.flow_status).to eq("Issued")
      expect(invoice.flow_message).to eq("ok")
      expect(invoice.rps_number).to eq(42)
      expect(invoice.rps_serial_number).to eq("A1")
      expect(invoice.check_code).to eq("ABC123")
      expect(invoice.city_service_code).to eq("01234")
      expect(invoice.modified_on).to eq("2026-01-02T00:00:00Z")
    end

    it "drops unknown keys and tolerates missing fields" do
      invoice = described_class.from_api("id" => "si_2", "unknownKey" => "ignored")
      expect(invoice.id).to eq("si_2")
      expect(invoice.flow_status).to be_nil
      expect(invoice).not_to respond_to(:unknown_key)
    end

    it "returns nil for a nil payload and is immutable" do
      expect(described_class.from_api(nil)).to be_nil
      expect(described_class.from_api("id" => "x")).to be_frozen
    end
  end
end
