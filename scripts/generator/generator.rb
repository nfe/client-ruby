# frozen_string_literal: true

require_relative "file_layout"
require_relative "spec_loader"
require_relative "name_mapper"
require_relative "type_mapper"
require_relative "schema_compiler"
require_relative "enum_compiler"
require_relative "ruby_emitter"
require_relative "rbs_emitter"

module Nfe
  module Build
    # Orchestrates discovery -> load -> compile -> emit across all specs in
    # openapi_dir, producing the full in-memory file map and writing it out.
    class Generator
      LIB_PREFIX = FileLayout::LIB_PREFIX
      SIG_PREFIX = FileLayout::SIG_PREFIX

      def initialize(openapi_dir:, name_mapper: NameMapper)
        @openapi_dir = openapi_dir.to_s
        @name_mapper = name_mapper
        @warnings = []
        @skipped = []
      end

      attr_reader :warnings, :skipped

      # relative path => contents, covering .rb + .rbs + loader + marker.
      def generate
        models = compile_all
        files = {}
        models.each { |m| emit_model(m, files) }
        files["#{LIB_PREFIX}.rb"] = loader_file(models)
        files["#{LIB_PREFIX}/generated_marker.rb"] = marker_file
        files.sort.to_h
      end

      def write_to(lib_root:, sig_root:)
        files = generate
        written = files.map { |rel, contents| FileLayout.write_file(rel, contents, lib_root, sig_root) }
        FileLayout.prune_stale(files.keys, lib_root, sig_root)
        written.sort
      end

      def spec_loaders
        @spec_loaders ||= spec_paths.map { |path| SpecLoader.new(path) }
      end

      private

      def spec_paths
        Dir.glob(File.join(@openapi_dir, "*.{yaml,json}"))
      end

      def compile_all
        spec_loaders.flat_map { |loader| compile_spec(loader) }.sort_by { |m| [m[:module_path], m[:file_snake]] }
      end

      def compile_spec(loader)
        schemas = loader.schemas
        if schemas.empty?
          @skipped << loader.basename
          return []
        end

        context = context_for(loader, schemas)
        schemas.sort.flat_map { |name, schema| compile_schema(name, schema, context) }
      end

      def context_for(loader, schemas)
        type_mapper = TypeMapper.new(schema_names: schemas.keys, schemas: schemas)
        {
          type_mapper: type_mapper,
          schema_compiler: SchemaCompiler.new(name_mapper: @name_mapper, type_mapper: type_mapper),
          enum_compiler: EnumCompiler.new(name_mapper: @name_mapper),
          namespace: @name_mapper.namespace_from_spec(loader.basename),
          module_path: @name_mapper.module_path_from_spec(loader.basename),
          source_spec: "openapi/#{loader.basename}",
          spec_hash: loader.hash
        }
      end

      def compile_schema(name, schema, context)
        kwargs = {
          namespace: context[:namespace], module_path: context[:module_path],
          source_spec: context[:source_spec], spec_hash: context[:spec_hash]
        }
        model = context[:enum_compiler].compile(name, schema, **kwargs) ||
                context[:schema_compiler].compile(name, schema, **kwargs)
        @warnings.concat(context[:type_mapper].warnings)
        model ? [model] : []
      end

      def emit_model(model, files)
        rel = "#{model[:module_path]}/#{model[:file_snake]}"
        files["#{LIB_PREFIX}/#{rel}.rb"] = RubyEmitter.emit(model)
        files["#{SIG_PREFIX}/#{rel}.rbs"] = RbsEmitter.emit(model)
      end

      def loader_file(models)
        requires = models.map do |m|
          "require_relative \"generated/#{m[:module_path]}/#{m[:file_snake]}\""
        end.sort.uniq
        lines = ["# frozen_string_literal: true", "# AUTO-GENERATED — do not edit", "",
                 "require_relative \"generated/generated_marker\""]
        lines.concat(requires)
        "#{lines.join("\n")}\n"
      end

      def marker_file
        specs = spec_loaders.reject { |l| l.schemas.empty? }
                            .sort_by(&:basename)
                            .map { |l| "      #{l.basename.inspect} => #{l.hash.inspect}" }
        lines = ["# frozen_string_literal: true", "# AUTO-GENERATED — do not edit", "",
                 "module Nfe", "  module Generated", "    MARKER = {", "      generated_at: nil,"]
        lines << "      specs: {"
        lines << specs.join(",\n")
        lines.push("      }", "    }.freeze", "  end", "end")
        "#{lines.join("\n")}\n"
      end
    end
  end
end
