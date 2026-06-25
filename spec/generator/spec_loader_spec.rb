# frozen_string_literal: true

require "tempfile"
require_relative "../../scripts/generator/spec_loader"

RSpec.describe Nfe::Build::SpecLoader do
  let(:fixture) { File.expand_path("../fixtures/openapi/minimal.yaml", __dir__) }

  def write_temp(contents, ext: ".yaml")
    file = Tempfile.new(["spec_loader", ext])
    file.write(contents)
    file.flush
    file.path
  end

  describe "#schemas" do
    it "returns the components.schemas map keyed by schema name" do
      loader = described_class.new(fixture)

      expect(loader.schemas.keys).to include("Borrower", "Address", "InvoiceStatus")
    end

    it "exposes each schema as a Hash fragment" do
      loader = described_class.new(fixture)

      expect(loader.schemas.fetch("Borrower")).to include("type" => "object")
    end

    it "returns an empty hash when components.schemas is absent" do
      path = write_temp("openapi: \"3.0.0\"\ninfo:\n  title: Empty\n")

      expect(described_class.new(path).schemas).to eq({})
    end
  end

  describe "#path and #basename" do
    it "exposes the file path and basename" do
      loader = described_class.new(fixture)

      expect(loader.path).to eq(fixture)
      expect(loader.basename).to eq("minimal.yaml")
    end
  end

  describe "#hash" do
    it "is the sha256 of the raw bytes, prefixed sha256:" do
      loader = described_class.new(fixture)
      raw = File.binread(fixture)
      expected = "sha256:#{Digest::SHA256.hexdigest(raw)}"

      expect(loader.hash).to eq(expected)
    end

    it "is stable across repeated reads of the same file" do
      first = described_class.new(fixture).hash
      second = described_class.new(fixture).hash

      expect(first).to eq(second)
    end
  end

  describe "JSON support" do
    it "parses a JSON document through Psych" do
      json = "{\"openapi\":\"3.0.0\",\"components\":{\"schemas\":{\"Foo\":{\"type\":\"object\"}}}}"
      path = write_temp(json, ext: ".json")

      expect(described_class.new(path).schemas.keys).to eq(["Foo"])
    end
  end

  describe "validation failures" do
    it "raises Nfe::Build::Error when the file cannot be parsed" do
      path = write_temp("key: value\n  bad: : indentation\n:::")

      expect { described_class.new(path) }.to raise_error(Nfe::Build::Error)
    end

    it "raises Nfe::Build::Error when the parsed root is not a Hash" do
      path = write_temp("- just\n- a\n- list\n")

      expect { described_class.new(path) }.to raise_error(Nfe::Build::Error)
    end

    it "raises Nfe::Build::Error when neither openapi nor swagger key is present" do
      path = write_temp("info:\n  title: No version key\n")

      expect { described_class.new(path) }.to raise_error(Nfe::Build::Error)
    end

    it "accepts a swagger document" do
      path = write_temp("swagger: \"2.0\"\ninfo:\n  title: Legacy\n")

      expect { described_class.new(path) }.not_to raise_error
    end
  end
end
