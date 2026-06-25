# frozen_string_literal: true

require_relative "../../scripts/generator/type_mapper"

RSpec.describe Nfe::Build::TypeMapper do
  subject(:mapper) { described_class.new(schema_names: %w[Address Document]) }

  describe "#rbs_type primitives" do
    it "maps the primitive scalar types" do
      expect(mapper.rbs_type("type" => "string")).to eq("String")
      expect(mapper.rbs_type("type" => "integer")).to eq("Integer")
      expect(mapper.rbs_type("type" => "number")).to eq("Float")
      expect(mapper.rbs_type("type" => "boolean")).to eq("bool")
    end

    it "maps a free-form object to Hash[String, untyped]" do
      expect(mapper.rbs_type("type" => "object")).to eq("Hash[String, untyped]")
    end

    it "treats date and date-time formats as String" do
      expect(mapper.rbs_type("type" => "string", "format" => "date-time")).to eq("String")
      expect(mapper.rbs_type("type" => "string", "format" => "date")).to eq("String")
    end
  end

  describe "#rbs_type refs" do
    it "resolves a known local $ref to its class name" do
      expect(mapper.rbs_type("$ref" => "#/components/schemas/Address")).to eq("Address")
    end

    it "falls back to untyped for an unknown local $ref" do
      expect(mapper.rbs_type("$ref" => "#/components/schemas/Unknown")).to eq("untyped")
    end

    it "falls back to untyped for a cross-file $ref" do
      expect(mapper.rbs_type("$ref" => "other.yaml#/components/schemas/Address")).to eq("untyped")
    end
  end

  describe "#rbs_type arrays" do
    it "maps an array of a primitive item type" do
      expect(mapper.rbs_type("type" => "array", "items" => { "type" => "string" }))
        .to eq("Array[String]")
    end

    it "maps an array of a $ref item type" do
      expect(mapper.rbs_type("type" => "array", "items" => { "$ref" => "#/components/schemas/Document" }))
        .to eq("Array[Document]")
    end

    it "maps an array without items to Array[untyped]" do
      expect(mapper.rbs_type("type" => "array")).to eq("Array[untyped]")
    end
  end

  describe "#rbs_type nullable" do
    it "suffixes a nullable type with ?" do
      expect(mapper.rbs_type("type" => "string", "nullable" => true)).to eq("String?")
    end
  end

  describe "#rbs_type oneOf" do
    it "maps a oneOf of primitives to an RBS union" do
      fragment = { "oneOf" => [{ "type" => "integer" }, { "type" => "string" }] }

      expect(mapper.rbs_type(fragment)).to eq("Integer | String")
    end

    it "maps a oneOf of objects to untyped" do
      fragment = { "oneOf" => [
        { "$ref" => "#/components/schemas/Address" },
        { "$ref" => "#/components/schemas/Document" }
      ] }

      expect(mapper.rbs_type(fragment)).to eq("untyped")
    end
  end

  describe "#ref_target" do
    it "returns the class name for a known local $ref" do
      expect(mapper.ref_target("$ref" => "#/components/schemas/Address")).to eq("Address")
    end

    it "returns nil for a non-ref fragment" do
      expect(mapper.ref_target("type" => "string")).to be_nil
    end
  end

  describe "#array_ref_target" do
    it "returns the item class name for an array of a known $ref" do
      fragment = { "type" => "array", "items" => { "$ref" => "#/components/schemas/Document" } }

      expect(mapper.array_ref_target(fragment)).to eq("Document")
    end

    it "returns nil for an array of primitives" do
      fragment = { "type" => "array", "items" => { "type" => "string" } }

      expect(mapper.array_ref_target(fragment)).to be_nil
    end
  end
end
