# frozen_string_literal: true

RSpec.describe Nfe::NfeFileResource do
  describe ".from_api" do
    it "maps the uri and metadata fields" do
      file = described_class.from_api(
        "uri" => "https://files.nfse.io/abc.pdf",
        "name" => "abc.pdf",
        "contentType" => "application/pdf",
        "size" => 1024
      )

      expect(file.uri).to eq("https://files.nfse.io/abc.pdf")
      expect(file.name).to eq("abc.pdf")
      expect(file.content_type).to eq("application/pdf")
      expect(file.size).to eq(1024)
    end

    it "falls back to the url key when uri is absent" do
      file = described_class.from_api("url" => "https://files.nfse.io/x.xml")
      expect(file.uri).to eq("https://files.nfse.io/x.xml")
    end

    it "returns nil for a nil payload" do
      expect(described_class.from_api(nil)).to be_nil
    end
  end
end
