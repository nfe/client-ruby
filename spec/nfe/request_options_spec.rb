# frozen_string_literal: true

RSpec.describe Nfe::RequestOptions do
  it "defaults every field to nil" do
    options = described_class.new

    expect(options.api_key).to be_nil
    expect(options.base_url).to be_nil
    expect(options.timeout).to be_nil
  end

  it "carries the supplied per-call overrides" do
    options = described_class.new(api_key: "tenant-key", base_url: "https://staging.example", timeout: 90)

    expect(options.api_key).to eq("tenant-key")
    expect(options.base_url).to eq("https://staging.example")
    expect(options.timeout).to eq(90)
  end

  it "allows overriding only a subset of fields" do
    options = described_class.new(timeout: 90)

    expect(options.timeout).to eq(90)
    expect(options.api_key).to be_nil
    expect(options.base_url).to be_nil
  end

  it "is frozen and compares by value" do
    a = described_class.new(api_key: "k")
    b = described_class.new(api_key: "k")

    expect(a).to be_frozen
    expect(a).to eq(b)
  end
end
