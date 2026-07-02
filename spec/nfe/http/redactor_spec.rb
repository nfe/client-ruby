# frozen_string_literal: true

RSpec.describe Nfe::Http::Redactor do
  describe ".headers" do
    it "redacts the canonical sensitive headers regardless of casing" do
      input = {
        "X-NFE-APIKEY" => "sk_live_secret",
        "Authorization" => "Bearer abc",
        "Idempotency-Key" => "9f1c"
      }

      result = described_class.headers(input)

      expect(result.values).to all(eq("[REDACTED]"))
    end

    it "redacts any header matching secret/apikey/token" do
      input = {
        "X-Client-Secret" => "shh",
        "App-Token" => "t0ken",
        "Some-Apikey-Header" => "k"
      }

      expect(described_class.headers(input).values).to all(eq("[REDACTED]"))
    end

    it "leaves benign headers untouched" do
      input = { "Content-Type" => "application/json", "Accept" => "application/json" }

      expect(described_class.headers(input)).to eq(input)
    end

    it "does not mutate the input hash" do
      input = { "Authorization" => "Bearer abc" }

      described_class.headers(input)

      expect(input["Authorization"]).to eq("Bearer abc")
    end

    it "returns a new hash with mixed sensitive and benign keys" do
      input = { "Authorization" => "Bearer abc", "Accept" => "application/json" }

      result = described_class.headers(input)

      expect(result).to eq("Authorization" => "[REDACTED]", "Accept" => "application/json")
    end
  end

  describe ".sensitive?" do
    it "matches by exact name and by pattern, case-insensitively" do
      expect(described_class.sensitive?("authorization")).to be(true)
      expect(described_class.sensitive?(:"X-NFE-APIKEY")).to be(true)
      expect(described_class.sensitive?("My-Secret")).to be(true)
      expect(described_class.sensitive?("Content-Type")).to be(false)
    end
  end
end
