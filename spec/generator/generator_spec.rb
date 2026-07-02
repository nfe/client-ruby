# frozen_string_literal: true

require "tmpdir"
require_relative "../../scripts/generator/name_mapper"
require_relative "../../scripts/generator/generator"

RSpec.describe Nfe::Build::Generator do
  subject(:generator) do
    described_class.new(openapi_dir: openapi_dir, name_mapper: Nfe::Build::NameMapper)
  end

  let(:openapi_dir) { File.expand_path("../fixtures/openapi", __dir__) }

  describe "#generate" do
    subject(:output) { generator.generate }

    it "returns both .rb and .rbs entries keyed by relative path" do
      rb = output.keys.select { |k| k.end_with?(".rb") }
      rbs = output.keys.select { |k| k.end_with?(".rbs") }

      expect(rb).not_to be_empty
      expect(rbs).not_to be_empty
    end

    it "writes value objects under lib/nfe/generated and signatures under sig/nfe/generated" do
      expect(output.keys).to include(
        a_string_matching(%r{\Alib/nfe/generated/minimal/}),
        a_string_matching(%r{\Asig/nfe/generated/minimal/})
      )
    end

    it "includes the require_relative loader and the generated marker" do
      expect(output).to have_key("lib/nfe/generated.rb")
      expect(output).to have_key("lib/nfe/generated/generated_marker.rb")
    end

    it "records the spec hash in the marker" do
      expect(output.fetch("lib/nfe/generated/generated_marker.rb")).to include("sha256:")
    end

    it "is deterministic — generating twice yields byte-identical output" do
      expect(generator.generate).to eq(output)
    end
  end

  describe "#write_to" do
    it "writes both trees and returns the list of written paths" do
      Dir.mktmpdir do |root|
        lib_root = File.join(root, "lib")
        sig_root = File.join(root, "sig")

        written = generator.write_to(lib_root: lib_root, sig_root: sig_root)

        expect(written).not_to be_empty
        expect(written).to include(a_string_matching(%r{lib/nfe/generated/minimal/}))
        expect(written).to include(a_string_matching(%r{sig/nfe/generated/minimal/}))
        expect(written).to all(satisfy { |path| File.exist?(path) })
      end
    end
  end
end
