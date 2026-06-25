# frozen_string_literal: true

RSpec.describe Nfe::LegalPerson do
  describe ".from_api" do
    it "maps camelCase keys onto snake_case members" do
      person = described_class.from_api(
        "id" => "lp_1",
        "name" => "Fornecedor SA",
        "tradeName" => "Fornecedor",
        "federalTaxNumber" => "11222333000181",
        "email" => "contato@fornecedor.com",
        "createdOn" => "2026-01-01T00:00:00Z"
      )

      expect(person.id).to eq("lp_1")
      expect(person.name).to eq("Fornecedor SA")
      expect(person.trade_name).to eq("Fornecedor")
      expect(person.federal_tax_number).to eq("11222333000181")
      expect(person.email).to eq("contato@fornecedor.com")
      expect(person.created_on).to eq("2026-01-01T00:00:00Z")
    end

    it "keeps the CNPJ as a String even when numeric" do
      person = described_class.from_api("federalTaxNumber" => 11_222_333_000_181)
      expect(person.federal_tax_number).to eq("11222333000181")
    end

    it "drops unknown keys and tolerates missing fields" do
      person = described_class.from_api("id" => "lp_2", "weird" => 1)
      expect(person.id).to eq("lp_2")
      expect(person.name).to be_nil
    end

    it "returns nil for a nil payload" do
      expect(described_class.from_api(nil)).to be_nil
    end
  end
end
