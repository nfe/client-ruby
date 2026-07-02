# frozen_string_literal: true

module Nfe
  module Build
    # Renders an internal model (:data / :enum / :alias) to .rb file contents.
    # Deterministic indentation and ordering; from_api is the only method on
    # data value objects.
    module RubyEmitter
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
          "# frozen_string_literal: true",
          "# AUTO-GENERATED — do not edit",
          "# Source: #{model[:source_spec]}",
          "# Hash: #{model[:spec_hash]}"
        ].join("\n")
      end

      def emit_data(model)
        body = [
          "#{banner(model)}\n",
          "module Nfe",
          "  module Generated",
          "    module #{model[:namespace]}",
          data_define(model),
          "    end",
          "  end",
          "end"
        ]
        "#{body.join("\n")}\n"
      end

      def data_define(model)
        members = model[:attributes].map { |a| ":#{a[:ruby_name]}" }.join(", ")
        [
          "      #{model[:const]} = Data.define(#{members}) do",
          from_api_method(model),
          "      end"
        ].join("\n")
      end

      def from_api_method(model)
        lines = ["        def self.from_api(payload)", "          return nil if payload.nil?", "", "          new("]
        model[:attributes].each { |attr| lines << "            #{attr[:ruby_name]}: #{from_api_value(attr)}," }
        lines << "          )"
        lines << "        end"
        lines.join("\n")
      end

      def from_api_value(attr)
        key = attr[:original_name].inspect
        if attr[:ref_target]
          "#{attr[:ref_target]}.from_api(payload[#{key}])"
        elsif attr[:array_ref_target]
          "(payload[#{key}] || []).map { |e| #{attr[:array_ref_target]}.from_api(e) }"
        else
          "payload[#{key}]"
        end
      end

      def emit_enum(model)
        body = ["#{banner(model)}\n", "module Nfe", "  module Generated", "    module #{model[:namespace]}",
                "      module #{model[:const]}"]
        model[:entries].each { |e| body << "        #{e[:const_name]} = #{enum_literal(e[:value], model[:backing])}" }
        body << "        ALL = [#{model[:entries].map { |e| e[:const_name] }.join(', ')}].freeze"
        body.push("      end", "    end", "  end", "end")
        "#{body.join("\n")}\n"
      end

      def enum_literal(value, backing)
        backing == :integer ? value.to_s : value.to_s.inspect
      end

      def emit_alias(model)
        body = [
          "#{banner(model)}\n",
          "module Nfe",
          "  module Generated",
          "    module #{model[:namespace]}",
          "      # free-form object: #{model[:rbs_type]}",
          "      #{model[:const]} = Hash",
          "    end",
          "  end",
          "end"
        ]
        "#{body.join("\n")}\n"
      end
    end
  end
end
