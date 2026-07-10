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
        "modifiedOn" => "2026-01-02T00:00:00Z",
        "baseTaxAmount" => 1000.0,
        "issRate" => 0.05,
        "issTaxAmount" => 50.0,
        "borrower" => { "name" => "ACME LTDA", "federalTaxNumber" => 191 }
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

    it "maps the ISS tax fields" do
      invoice = described_class.from_api(payload)

      expect(invoice.base_tax_amount).to eq(1000.0)
      expect(invoice.iss_rate).to eq(0.05)
      expect(invoice.iss_tax_amount).to eq(50.0)
    end

    it "hydrates borrower into a ServiceInvoiceBorrower" do
      borrower = described_class.from_api(payload).borrower

      expect(borrower).to be_a(Nfe::ServiceInvoiceBorrower)
      expect(borrower.name).to eq("ACME LTDA")
    end

    it "preserves unknown keys under raw and tolerates missing fields" do
      invoice = described_class.from_api(
        "id" => "si_2",
        "taxationType" => "WithinCity",
        "issAmountWithheld" => 12.5,
        "provider" => { "id" => "co_1" }
      )

      expect(invoice.id).to eq("si_2")
      expect(invoice.flow_status).to be_nil
      expect(invoice).not_to respond_to(:taxation_type)
      expect(invoice.raw["taxationType"]).to eq("WithinCity")
      expect(invoice.raw["issAmountWithheld"]).to eq(12.5)
      expect(invoice.raw.dig("provider", "id")).to eq("co_1")
    end

    it "keeps raw as the complete payload, including typed fields" do
      invoice = described_class.from_api(payload)
      expect(invoice.raw).to eq(payload)
    end

    it "leaves the deprecated pdf/xml ghosts nil on a real retrieve payload" do
      invoice = described_class.from_api(payload)
      expect(invoice.pdf).to be_nil
      expect(invoice.xml).to be_nil
    end

    it "returns nil for a nil payload and is immutable" do
      expect(described_class.from_api(nil)).to be_nil
      expect(described_class.from_api("id" => "x")).to be_frozen
    end
  end
end
