# frozen_string_literal: true

RSpec.describe Nfe::Configuration do
  subject(:config) { described_class.new(api_key: "key") }

  # Keep the suite deterministic regardless of the developer's shell: by
  # default neither env key is present unless a specific example sets it.
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NFE_API_KEY").and_return(nil)
    allow(ENV).to receive(:[]).with("NFE_DATA_API_KEY").and_return(nil)
  end

  describe "defaults" do
    it "applies sensible defaults" do
      expect(config.environment).to eq(:production)
      expect(config.timeout).to eq(described_class::DEFAULT_TIMEOUT)
      expect(config.timeout).to be > 0
      expect(config.open_timeout).to be > 0
      expect(config.max_retries).to be >= 0
      expect(config.ca_file).to be_nil
      expect(config.ca_path).to be_nil
      expect(config.proxy).to be_nil
      expect(config.base_url_overrides).to eq({})
    end
  end

  describe "validation" do
    it "rejects an empty api_key when no data_api_key or env key is present" do
      expect { described_class.new(api_key: "") }
        .to raise_error(Nfe::ConfigurationError)
    end

    it "rejects when no key is provided at all" do
      expect { described_class.new }
        .to raise_error(Nfe::ConfigurationError)
    end

    it "rejects an invalid environment" do
      expect { described_class.new(api_key: "k", environment: :sandbox) }
        .to raise_error(Nfe::ConfigurationError, /environment/)
    end

    it "rejects a non-positive timeout" do
      expect { described_class.new(api_key: "k", timeout: 0) }
        .to raise_error(Nfe::ConfigurationError, /timeout/)
    end

    it "rejects a negative max_retries" do
      expect { described_class.new(api_key: "k", max_retries: -1) }
        .to raise_error(Nfe::ConfigurationError, /max_retries/)
    end

    it "constructs with only a data_api_key" do
      cfg = described_class.new(data_api_key: "d")
      expect(cfg.data_api_key).to eq("d")
      expect(cfg.api_key).to be_nil
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

    it "resolves main-family aliases to the main host" do
      %i[companies service_invoices legal_people natural_people webhooks].each do |alias_family|
        expect(config.base_url_for(alias_family)).to eq("https://api.nfe.io")
      end
    end

    it "resolves cte-family aliases to the cte host" do
      %i[transportation transportation_invoices inbound_product inbound_product_invoices
         product_invoices consumer_invoices tax_calculation tax_codes state_taxes].each do |alias_family|
        expect(config.base_url_for(alias_family)).to eq("https://api.nfse.io")
      end
    end

    it "resolves query aliases to the nfe-query host" do
      expect(config.base_url_for(:product_invoice_query)).to eq("https://nfe.api.nfe.io")
      expect(config.base_url_for(:consumer_invoice_query)).to eq("https://nfe.api.nfe.io")
    end

    it "falls back to the main host for an unknown family" do
      expect(config.base_url_for(:something_unknown)).to eq("https://api.nfe.io")
    end

    it "honors a per-family override" do
      overridden = described_class.new(api_key: "k", base_url_overrides: { cte: "https://staging.example" })
      expect(overridden.base_url_for(:cte)).to eq("https://staging.example")
    end
  end

  describe "#api_key_for" do
    it "uses the data key for data families when present" do
      cfg = described_class.new(api_key: "main", data_api_key: "data")
      expect(cfg.api_key_for(:addresses)).to eq("data")
      expect(cfg.api_key_for(:legal_entity)).to eq("data")
      expect(cfg.api_key_for(:natural_person)).to eq("data")
      expect(cfg.api_key_for(:nfe_query)).to eq("data")
    end

    it "falls back to the main key for data families when no data key is set" do
      cfg = described_class.new(api_key: "main")
      expect(cfg.api_key_for(:nfe_query)).to eq("main")
    end

    it "always uses the main key for main families even with a data key set" do
      cfg = described_class.new(api_key: "main", data_api_key: "data")
      expect(cfg.api_key_for(:main)).to eq("main")
      expect(cfg.api_key_for(:companies)).to eq("main")
    end

    it "raises when no key resolves for the accessed family" do
      cfg = described_class.new(data_api_key: "data")
      expect { cfg.api_key_for(:companies) }
        .to raise_error(Nfe::ConfigurationError)
    end
  end

  describe "environment-variable fallback" do
    around do |example|
      saved = ENV.values_at("NFE_API_KEY", "NFE_DATA_API_KEY")
      ENV.delete("NFE_API_KEY")
      ENV.delete("NFE_DATA_API_KEY")
      example.run
    ensure
      ENV["NFE_API_KEY"], ENV["NFE_DATA_API_KEY"] = saved
    end

    it "adopts NFE_API_KEY when no explicit api_key is given" do
      ENV["NFE_API_KEY"] = "from-env"
      expect(described_class.new.api_key).to eq("from-env")
    end

    it "adopts NFE_DATA_API_KEY when no explicit data_api_key is given" do
      ENV["NFE_DATA_API_KEY"] = "data-env"
      expect(described_class.new(api_key: "main").data_api_key).to eq("data-env")
    end

    it "lets an explicit argument win over the environment value" do
      ENV["NFE_API_KEY"] = "from-env"
      expect(described_class.new(api_key: "explicit").api_key).to eq("explicit")
    end
  end

  describe "TLS trust surface" do
    it "honors a custom CA bundle without exposing a way to disable verification" do
      cfg = described_class.new(api_key: "k", ca_file: "/path/to/corporate-ca.pem")
      expect(cfg.ca_file).to eq("/path/to/corporate-ca.pem")
      expect(cfg).not_to respond_to(:insecure_ssl)
      expect(cfg).not_to respond_to(:verify_none)
      expect(cfg).not_to respond_to(:verify_mode)
    end
  end
end
