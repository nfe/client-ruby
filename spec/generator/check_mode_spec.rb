# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "../../scripts/generator/name_mapper"
require_relative "../../scripts/generator/generator"
require_relative "../../scripts/generator/check_mode"

RSpec.describe Nfe::Build::CheckMode do
  let(:openapi_dir) { File.expand_path("../fixtures/openapi", __dir__) }
  let(:generator) do
    Nfe::Build::Generator.new(openapi_dir: openapi_dir, name_mapper: Nfe::Build::NameMapper)
  end

  def with_generated_trees
    Dir.mktmpdir do |root|
      lib_root = File.join(root, "lib")
      sig_root = File.join(root, "sig")
      generator.write_to(lib_root: lib_root, sig_root: sig_root)
      yield(lib_root, sig_root)
    end
  end

  it "reports ok with no drift after a fresh write" do
    with_generated_trees do |lib_root, sig_root|
      result = described_class.diff(generator: generator, lib_root: lib_root, sig_root: sig_root)

      expect(result).to include(ok: true, added: [], removed: [], changed: [])
    end
  end

  it "detects a changed file" do
    with_generated_trees do |lib_root, sig_root|
      target = Dir.glob(File.join(lib_root, "nfe/generated/minimal/*.rb")).first
      File.write(target, "# hand-edited drift\n", mode: "a")

      result = described_class.diff(generator: generator, lib_root: lib_root, sig_root: sig_root)

      expect(result[:ok]).to be(false)
      expect(result[:changed]).not_to be_empty
    end
  end

  it "detects a missing file as added" do
    with_generated_trees do |lib_root, sig_root|
      target = Dir.glob(File.join(lib_root, "nfe/generated/minimal/*.rb")).first
      FileUtils.rm(target)

      result = described_class.diff(generator: generator, lib_root: lib_root, sig_root: sig_root)

      expect(result[:ok]).to be(false)
      expect(result[:added]).not_to be_empty
    end
  end

  it "detects an extra checked-in file as removed" do
    with_generated_trees do |lib_root, sig_root|
      stale = File.join(lib_root, "nfe/generated/minimal/stale_dto.rb")
      File.write(stale, "# frozen_string_literal: true\n")

      result = described_class.diff(generator: generator, lib_root: lib_root, sig_root: sig_root)

      expect(result[:ok]).to be(false)
      expect(result[:removed]).not_to be_empty
    end
  end
end
