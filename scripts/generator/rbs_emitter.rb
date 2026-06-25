# frozen_string_literal: true

module Nfe
  module Build
    # Renders an internal model to .rbs signature contents mirroring the .rb.
    # Output must pass `rbs validate`.
    module RbsEmitter
      module_function

      def emit(model)
        case model[:kind]
        when :data then emit_data(model)
        when :enum then emit_enum(model)
        when :alias then emit_alias(model)
        else
          raise ArgumentError, "Unknown model kind: #{model[:kind].inspect}"
        end
      end

      def banner(model)
        [
          "# AUTO-GENERATED — do not edit",
          "# Source: #{model[:source_spec]}",
          "# Hash: #{model[:spec_hash]}"
        ].join("\n")
      end

      def emit_data(model)
        body = ["#{banner(model)}\n", "module Nfe", "  module Generated", "    module #{model[:namespace]}",
                "      class #{model[:const]} < Data"]
        model[:attributes].each { |a| body << "        attr_reader #{a[:ruby_name]}: #{a[:rbs_type]}" }
        body << new_signature(model, "self.new", "instance")
        body << new_signature(model, "initialize", "void")
        body << "        def self.from_api: (Hash[String, untyped]? payload) -> instance?"
        body.push("      end", "    end", "  end", "end")
        "#{body.join("\n")}\n"
      end

      def new_signature(model, method, return_type)
        params = model[:attributes].map do |attr|
          prefix = attr[:required] ? "" : "?"
          "#{prefix}#{attr[:ruby_name]}: #{attr[:rbs_type]}"
        end.join(", ")
        "        def #{method}: (#{params}) -> #{return_type}"
      end

      def emit_enum(model)
        body = ["#{banner(model)}\n", "module Nfe", "  module Generated", "    module #{model[:namespace]}",
                "      module #{model[:const]}"]
        literal = model[:backing] == :integer ? "Integer" : "String"
        model[:entries].each { |e| body << "        #{e[:const_name]}: #{literal}" }
        body << "        ALL: Array[#{literal}]"
        body.push("      end", "    end", "  end", "end")
        "#{body.join("\n")}\n"
      end

      def emit_alias(model)
        body = [
          "#{banner(model)}\n",
          "module Nfe",
          "  module Generated",
          "    module #{model[:namespace]}",
          "      #{model[:const]}: Hash[String, untyped]",
          "    end",
          "  end",
          "end"
        ]
        "#{body.join("\n")}\n"
      end
    end
  end
end
