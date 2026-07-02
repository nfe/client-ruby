#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "generator/generator"
require_relative "generator/check_mode"

# CLI entry point for the OpenAPI -> Ruby generator. Default writes generation;
# --check runs the sync guard (exit 1 on drift). Not shipped in the gem.
module Nfe
  module Build
    # Parses argv and runs the generator in write or check mode.
    class CLI
      ROOT = File.expand_path("..", __dir__)

      def self.run(argv)
        new(argv).run
      end

      def initialize(argv)
        @options = { check: false, spec: nil, verbose: false }
        parse(argv)
      end

      def run
        @options[:check] ? run_check : run_write
      end

      private

      def parse(argv)
        OptionParser.new do |o|
          o.on("--check", "Verify checked-in output matches the specs") { @options[:check] = true }
          o.on("--spec NAME", "Limit to a single spec basename") { |v| @options[:spec] = v }
          o.on("--verbose", "Print warnings and skipped specs") { @options[:verbose] = true }
        end.parse(argv)
      end

      def generator
        @generator ||= Generator.new(openapi_dir: File.join(ROOT, "openapi"))
      end

      def lib_root
        File.join(ROOT, "lib")
      end

      def sig_root
        File.join(ROOT, "sig")
      end

      def run_write
        written = generator.write_to(lib_root: lib_root, sig_root: sig_root)
        report
        puts "Generated #{written.length} files."
      end

      def run_check
        result = CheckMode.diff(generator: generator, lib_root: lib_root, sig_root: sig_root)
        report
        if result[:ok]
          puts "Generated output is in sync."
          exit 0
        end
        print_drift(result)
        exit 1
      end

      def print_drift(result)
        puts "Generated output is OUT OF SYNC. Run `rake generate`."
        %i[added removed changed].each do |key|
          result[key].each { |path| puts "  #{key}: #{path}" }
        end
      end

      def report
        return unless @options[:verbose]

        generator.skipped.each { |s| warn "skipped (no schemas): #{s}" }
        generator.warnings.uniq.each { |w| warn "warning: #{w}" }
      end
    end
  end
end

Nfe::Build::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
