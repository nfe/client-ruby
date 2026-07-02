# frozen_string_literal: true

require_relative "../../scripts/generator/name_mapper"
require_relative "../../scripts/generator/enum_compiler"

RSpec.describe Nfe::Build::EnumCompiler do
  subject(:compiler) { described_class.new(name_mapper: Nfe::Build::NameMapper) }

  def compile(name, schema)
    compiler.compile(
      name, schema,
      namespace: "MinimalV1", module_path: "minimal_v1",
      source_spec: "openapi/minimal.yaml", spec_hash: "sha256:abc"
    )
  end

  describe "#compile string-backed enum" do
    let(:schema) { { "type" => "string", "enum" => %w[Issued Cancelled] } }

    it "produces an :enum model backed by string" do
      model = compile("InvoiceStatus", schema)

      expect(model).to include(kind: :enum, const: "InvoiceStatus", backing: :string)
    end

    it "maps each value to a constant entry preserving the value" do
      entries = compile("InvoiceStatus", schema).fetch(:entries)

      expect(entries).to include(
        a_hash_including(const_name: "Issued", value: "Issued"),
        a_hash_including(const_name: "Cancelled", value: "Cancelled")
      )
    end
  end

  describe "#compile integer-backed enum" do
    let(:schema) { { "type" => "integer", "enum" => [1, 2, 3] } }

    it "produces an :enum model backed by integer" do
      model = compile("Priority", schema)

      expect(model).to include(kind: :enum, backing: :integer)
      expect(model.fetch(:entries).map { |e| e[:value] }).to eq([1, 2, 3])
    end
  end

  describe "#compile non-enum schema" do
    it "returns nil when the schema has no enum key" do
      schema = { "type" => "object", "properties" => {} }

      expect(compile("Borrower", schema)).to be_nil
    end
  end

  describe "#compile constant collision" do
    let(:schema) { { "type" => "string", "enum" => ["a-b", "a.b"] } }

    it "resolves colliding constant names deterministically" do
      names = compile("Collide", schema).fetch(:entries).map { |e| e[:const_name] }

      expect(names.uniq.length).to eq(names.length)
    end
  end
end
