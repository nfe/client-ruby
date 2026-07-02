# frozen_string_literal: true

RSpec.describe Nfe::Http::Response do
  describe "defaults" do
    it "defaults headers and body" do
      response = described_class.new(status: 204)

      expect(response.headers).to eq({})
      expect(response.body).to be_nil
    end
  end

  describe "#header" do
    let(:response) do
      described_class.new(status: 200, headers: { "content-type" => "application/json" })
    end

    it "looks up headers case-insensitively" do
      expect(response.header("Content-Type")).to eq("application/json")
      expect(response.header("content-type")).to eq("application/json")
      expect(response.header("CONTENT-TYPE")).to eq("application/json")
    end

    it "returns nil for an absent header" do
      expect(response.header("X-Missing")).to be_nil
    end
  end

  describe "#success?" do
    it "is true for 2xx" do
      [200, 201, 204, 299].each do |status|
        expect(described_class.new(status: status).success?).to be(true)
      end
    end

    it "is false for 3xx and 4xx" do
      [301, 302, 400, 404, 500].each do |status|
        expect(described_class.new(status: status).success?).to be(false)
      end
    end
  end

  describe "#location" do
    it "returns the Location header regardless of casing" do
      response = described_class.new(status: 202, headers: { "location" => "/v1/invoices/123" })

      expect(response.location).to eq("/v1/invoices/123")
      expect(response.header("Location")).to eq("/v1/invoices/123")
    end

    it "returns nil when no Location header is present" do
      expect(described_class.new(status: 200).location).to be_nil
    end
  end

  describe "binary body" do
    it "preserves raw bytes without transcoding" do
      bytes = "%PDF-1.4\x00\xFF\xFE".dup.force_encoding(Encoding::ASCII_8BIT)
      response = described_class.new(status: 200, body: bytes)

      expect(response.body.encoding).to eq(Encoding::ASCII_8BIT)
      expect(response.body.bytes).to eq(bytes.bytes)
    end
  end
end
