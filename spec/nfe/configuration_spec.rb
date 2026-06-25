# frozen_string_literal: true

RSpec.describe Nfe::Configuration do
  subject(:config) { described_class.new(api_key: "key") }

  describe "defaults" do
    it "applies sensible defaults" do
      expect(config.environment).to eq(:production)
      expect(config.timeout).to eq(described_class::DEFAULT_TIMEOUT)
      expect(config.max_retries).to be >= 0
    end
  end

  describe "#base_url_for" do
    it "maps each product family to its canonical host" do
      expect(config.base_url_for(:main)).to eq("https://api.nfe.io")
      expect(config.base_url_for(:addresses)).to eq("https://address.api.nfe.io/v2")
      expect(config.base_url_for(:nfe_query)).to eq("https://nfe.api.nfe.io")
      expect(config.base_url_for(:legal_entity)).to eq("https://legalentity.api.nfe.io")
      expect(config.base_url_for(:natural_person)).to eq("https://naturalperson.api.nfe.io")
      expect(config.base_url_for(:cte)).to eq("https://api.nfse.io")
    end

    it "falls back to the main host for an unknown family" do
      expect(config.base_url_for(:something_unknown)).to eq("https://api.nfe.io")
    end

    it "honors a per-family override" do
      overridden = described_class.new(api_key: "k", base_url_overrides: { cte: "https://staging.example" })
      expect(overridden.base_url_for(:cte)).to eq("https://staging.example")
    end
  end
end
