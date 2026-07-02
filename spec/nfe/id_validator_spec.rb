# frozen_string_literal: true

RSpec.describe Nfe::IdValidator do
  describe ".company_id" do
    it "returns the value when present" do
      expect(described_class.company_id("co-1")).to eq("co-1")
    end

    it "raises Nfe::InvalidRequestError on an empty value, naming the argument" do
      expect { described_class.company_id("") }
        .to raise_error(Nfe::InvalidRequestError, /company_id/)
    end

    it "raises on a whitespace-only value" do
      expect { described_class.company_id("   ") }.to raise_error(Nfe::InvalidRequestError)
    end
  end

  describe ".invoice_id" do
    it "returns the value when present and raises when empty" do
      expect(described_class.invoice_id("inv-9")).to eq("inv-9")
      expect { described_class.invoice_id("") }.to raise_error(Nfe::InvalidRequestError, /invoice_id/)
    end
  end

  describe ".state_tax_id" do
    it "returns the value when present and raises when empty" do
      expect(described_class.state_tax_id("st-1")).to eq("st-1")
      expect { described_class.state_tax_id(nil) }.to raise_error(Nfe::InvalidRequestError, /state_tax_id/)
    end
  end

  describe ".event_key" do
    it "returns the value when present and raises when empty" do
      expect(described_class.event_key("ev-1")).to eq("ev-1")
      expect { described_class.event_key("") }.to raise_error(Nfe::InvalidRequestError, /event_key/)
    end
  end

  describe ".access_key" do
    it "normalizes formatted input to 44 digits" do
      raw = "35261234567890123456789012345678901234567890" # 44 digits
      spaced = raw.chars.each_slice(4).map(&:join).join(" ")

      result = described_class.access_key(spaced)

      expect(result).to eq(raw)
      expect(result.length).to eq(44)
    end

    it "raises on a value of the wrong length" do
      expect { described_class.access_key("123") }.to raise_error(Nfe::InvalidRequestError, /44/)
    end
  end

  describe ".cnpj" do
    it "normalizes formatted input and returns a String, never an Integer" do
      result = described_class.cnpj("12.345.678/0001-90")

      expect(result).to eq("12345678000190")
      expect(result).to be_a(String)
    end

    it "preserves alphanumeric CNPJ (v3) without coercing to Integer" do
      result = described_class.cnpj("12ABC34501DE35")

      expect(result).to eq("12ABC34501DE35")
      expect(result).to be_a(String)
    end

    it "raises on the wrong length" do
      expect { described_class.cnpj("123") }.to raise_error(Nfe::InvalidRequestError, /CNPJ/)
    end

    it "raises on an empty value" do
      expect { described_class.cnpj("") }.to raise_error(Nfe::InvalidRequestError, /CNPJ/)
    end
  end

  describe ".cpf" do
    it "normalizes formatted input to 11 digits" do
      expect(described_class.cpf("123.456.789-09")).to eq("12345678909")
    end

    it "normalizes hyphen-and-dot formatted input to 11 digits" do
      expect(described_class.cpf("123.456.789-01")).to eq("12345678901")
    end

    it "raises on the wrong length" do
      expect { described_class.cpf("123") }.to raise_error(Nfe::InvalidRequestError, /CPF/)
    end

    it "raises on an empty value" do
      expect { described_class.cpf("") }.to raise_error(Nfe::InvalidRequestError, /CPF/)
    end
  end

  describe ".cep" do
    it "normalizes a hyphenated CEP to 8 digits" do
      expect(described_class.cep("01310-100")).to eq("01310100")
    end

    it "accepts an already-digits-only CEP" do
      expect(described_class.cep("01310100")).to eq("01310100")
    end

    it "raises on the wrong length" do
      expect { described_class.cep("123") }.to raise_error(Nfe::InvalidRequestError, /CEP/)
    end

    it "raises on an empty value" do
      expect { described_class.cep("") }.to raise_error(Nfe::InvalidRequestError, /CEP/)
    end
  end

  describe ".state" do
    it "uppercases and validates a UF" do
      expect(described_class.state("sp")).to eq("SP")
    end

    it "accepts the special EX and NA codes" do
      expect(described_class.state("ex")).to eq("EX")
      expect(described_class.state("na")).to eq("NA")
    end

    it "raises on an invalid UF" do
      expect { described_class.state("ZZ") }.to raise_error(Nfe::InvalidRequestError, /state/)
    end
  end
end
