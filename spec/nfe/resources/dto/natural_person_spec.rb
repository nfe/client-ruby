# frozen_string_literal: true

RSpec.describe Nfe::NaturalPerson do
  describe ".from_api" do
    it "maps camelCase keys onto snake_case members" do
      person = described_class.from_api(
        "id" => "np_1",
        "name" => "João da Silva",
        "federalTaxNumber" => "12345678901",
        "email" => "joao@example.com",
        "modifiedOn" => "2026-03-01T00:00:00Z"
      )

      expect(person.id).to eq("np_1")
      expect(person.name).to eq("João da Silva")
      expect(person.federal_tax_number).to eq("12345678901")
      expect(person.email).to eq("joao@example.com")
      expect(person.modified_on).to eq("2026-03-01T00:00:00Z")
    end

    it "keeps the CPF as a String even when numeric" do
      person = described_class.from_api("federalTaxNumber" => 12_345_678_901)
      expect(person.federal_tax_number).to eq("12345678901")
    end

    it "drops unknown keys and tolerates missing fields" do
      person = described_class.from_api("id" => "np_2", "extra" => true)
      expect(person.id).to eq("np_2")
      expect(person.name).to be_nil
    end

    it "returns nil for a nil payload" do
      expect(described_class.from_api(nil)).to be_nil
    end
  end
end
