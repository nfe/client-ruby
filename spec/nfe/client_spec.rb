# frozen_string_literal: true

RSpec.describe Nfe::Client do
  subject(:client) { described_class.new(api_key: "key") }

  it "instantiates with an API key and exposes its configuration" do
    expect(client).to be_a(described_class)
    expect(client.config).to be_a(Nfe::Configuration)
    expect(client.config.api_key).to eq("key")
  end

  it "accepts an injected configuration" do
    configuration = Nfe::Configuration.new(api_key: "k", timeout: 120)
    expect(described_class.new(configuration: configuration).config.timeout).to eq(120)
  end

  it "declares exactly seventeen core resource accessors" do
    expect(described_class::RESOURCES.size).to eq(17)
  end

  it "responds to every core resource accessor" do
    described_class::RESOURCES.each do |name|
      expect(client).to respond_to(name)
    end
  end

  it "leaves resource bodies for later changes" do
    expect { client.service_invoices }
      .to raise_error(NotImplementedError, /later change/)
  end
end
