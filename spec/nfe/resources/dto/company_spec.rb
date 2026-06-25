# frozen_string_literal: true

RSpec.describe Nfe::Company do
  describe ".from_api" do
    it "maps camelCase keys onto snake_case members" do
      company = described_class.from_api(
        "id" => "co_1",
        "name" => "Acme Ltda",
        "tradeName" => "Acme",
        "federalTaxNumber" => "12345678000199",
        "email" => "fiscal@acme.com",
        "municipalTaxNumber" => "987",
        "createdOn" => "2026-01-01T00:00:00Z",
        "modifiedOn" => "2026-02-01T00:00:00Z"
      )

      expect(company.id).to eq("co_1")
      expect(company.name).to eq("Acme Ltda")
      expect(company.trade_name).to eq("Acme")
      expect(company.federal_tax_number).to eq("12345678000199")
      expect(company.email).to eq("fiscal@acme.com")
      expect(company.municipal_tax_number).to eq("987")
      expect(company.created_on).to eq("2026-01-01T00:00:00Z")
      expect(company.modified_on).to eq("2026-02-01T00:00:00Z")
    end

    it "keeps a numeric federalTaxNumber as a String without coercion" do
      company = described_class.from_api("name" => "X", "federalTaxNumber" => 12_345_678_000_199)
      expect(company.federal_tax_number).to eq("12345678000199")
      expect(company.federal_tax_number).to be_a(String)
    end

    it "drops unknown keys and tolerates missing fields" do
      company = described_class.from_api("id" => "co_2", "unknownKey" => "ignored")
      expect(company.id).to eq("co_2")
      expect(company.name).to be_nil
      expect(company.federal_tax_number).to be_nil
      expect(company).not_to respond_to(:unknown_key)
    end

    it "returns nil for a nil payload" do
      expect(described_class.from_api(nil)).to be_nil
    end

    it "produces an immutable value object" do
      company = described_class.from_api("id" => "co_3")
      expect(company).to be_frozen
    end
  end
end
