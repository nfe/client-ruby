# frozen_string_literal: true

RSpec.describe Nfe::ServiceInvoiceBorrower do
  describe ".from_api" do
    let(:payload) do
      {
        "id" => "np_1",
        "name" => "ACME LTDA",
        "federalTaxNumber" => 191,
        "email" => "fiscal@acme.com.br",
        "phoneNumber" => "11999999999",
        "address" => { "city" => { "name" => "São Paulo" }, "state" => "SP" },
        "parentId" => "co_1"
      }
    end

    it "maps camelCase keys onto snake_case members" do
      borrower = described_class.from_api(payload)

      expect(borrower.id).to eq("np_1")
      expect(borrower.name).to eq("ACME LTDA")
      expect(borrower.email).to eq("fiscal@acme.com.br")
      expect(borrower.phone_number).to eq("11999999999")
      expect(borrower.parent_id).to eq("co_1")
      expect(borrower.address).to eq({ "city" => { "name" => "São Paulo" }, "state" => "SP" })
    end

    it "normalizes an Integer federalTaxNumber to String" do
      expect(described_class.from_api(payload).federal_tax_number).to eq("191")
    end

    it "preserves a String federalTaxNumber (alphanumeric CNPJ)" do
      borrower = described_class.from_api(payload.merge("federalTaxNumber" => "12ABC34501DE35"))
      expect(borrower.federal_tax_number).to eq("12ABC34501DE35")
    end

    it "returns nil for a nil payload and is immutable" do
      expect(described_class.from_api(nil)).to be_nil
      expect(described_class.from_api(payload)).to be_frozen
    end
  end

  describe "Hash-compatibility bridge" do
    let(:borrower) do
      described_class.from_api(
        "name" => "ACME LTDA",
        "federalTaxNumber" => 191,
        "address" => { "city" => { "name" => "São Paulo" } }
      )
    end

    it "keeps Hash-style reads working against the raw wire keys" do
      expect(borrower["name"]).to eq("ACME LTDA")
      expect(borrower["federalTaxNumber"]).to eq(191) # wire value, untouched
    end

    it "supports nested dig over the raw payload" do
      expect(borrower.dig("address", "city", "name")).to eq("São Paulo")
    end

    it "returns nil for absent keys, like a Hash" do
      expect(borrower["missing"]).to be_nil
      expect(borrower.dig("address", "missing")).to be_nil
    end
  end
end
