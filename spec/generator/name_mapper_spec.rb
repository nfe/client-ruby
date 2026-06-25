# frozen_string_literal: true

require_relative "../../scripts/generator/name_mapper"

RSpec.describe Nfe::Build::NameMapper do
  describe ".namespace_from_spec" do
    it "converts kebab/dot names to PascalCase and preserves version suffix" do
      expect(described_class.namespace_from_spec("service-invoice-rtc-v1.yaml"))
        .to eq("ServiceInvoiceRtcV1")
    end

    it "produces distinct namespaces for versioned and unversioned families" do
      expect(described_class.namespace_from_spec("consulta-cnpj.yaml")).to eq("ConsultaCnpj")
      expect(described_class.namespace_from_spec("consulta-cnpj-v3.yaml")).to eq("ConsultaCnpjV3")
    end

    it "handles a .json extension" do
      expect(described_class.namespace_from_spec("contribuintes-v2.json")).to eq("ContribuintesV2")
    end
  end

  describe ".module_path_from_spec" do
    it "snake_cases the basename without extension" do
      expect(described_class.module_path_from_spec("service-invoice-rtc-v1.yaml"))
        .to eq("service_invoice_rtc_v1")
    end
  end

  describe ".class_name" do
    it "keeps a valid constant unchanged" do
      expect(described_class.class_name("NFSeRequest")).to eq("NFSeRequest")
    end

    it "replaces invalid characters with underscore" do
      expect(described_class.class_name("Foo.Bar-Baz")).to eq("Foo_Bar_Baz")
    end

    it "capitalises a camelCase schema name into a constant" do
      expect(described_class.class_name("thirdPartyReimbursementDocument"))
        .to eq("ThirdPartyReimbursementDocument")
    end

    it "yields a valid constant when the name starts with a digit" do
      result = described_class.class_name("3DSecure")
      expect(result).to eq("N3DSecure")
      expect(result).to match(/\A[A-Z]/)
    end
  end

  describe ".file_snake" do
    it "snake_cases a constant for use as a filename" do
      expect(described_class.file_snake("NFSeRequest")).to eq("nfse_request")
    end
  end

  describe ".attr_name" do
    it "converts camelCase to snake_case" do
      expect(described_class.attr_name("federalTaxNumber")).to eq("federal_tax_number")
    end

    it "converts PascalCase to snake_case" do
      expect(described_class.attr_name("CityName")).to eq("city_name")
    end

    it "prefixes an underscore when it starts with a digit" do
      expect(described_class.attr_name("3rdParty")).to start_with("_")
    end

    it "suffixes reserved words with an underscore" do
      expect(described_class.attr_name("class")).to eq("class_")
      expect(described_class.attr_name("end")).to eq("end_")
    end
  end
end
