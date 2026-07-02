# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

# API reference (YARD) -> docs/api/ (config in .yardopts). Optional: the task is
# only defined when YARD is installed, so it never breaks the core tasks.
begin
  require "yard"
  YARD::Rake::YardocTask.new(:doc)
rescue LoadError
  nil
end

desc "Type-check lib/ against sig/ with Steep"
task :steep do
  sh "bundle exec steep check"
end

desc "Validate RBS signatures in sig/"
task :rbs do
  sh "bundle exec rbs validate"
end

desc "Generate Ruby value objects + RBS from openapi/*.{yaml,json}"
task :generate do
  sh "ruby scripts/generate.rb"
end

namespace :generate do
  desc "Fail if lib/nfe/generated + sig/nfe/generated drift from the OpenAPI specs"
  task :check do
    sh "ruby scripts/generate.rb --check"
  end
end

namespace :openapi do
  desc "Refresh openapi/ specs from nfeio-docs (NFEIO_DOCS_PATH); does not generate or commit"
  task :sync do
    require "fileutils"
    src = File.join(ENV.fetch("NFEIO_DOCS_PATH", "nfeio-docs"), "static", "api")
    raise "OpenAPI source not found: #{src}" unless File.directory?(src)

    Dir.glob("openapi/*.{yaml,json}").each do |dest|
      candidate = File.join(src, File.basename(dest))
      next puts("  missing-in-docs #{File.basename(dest)}") unless File.file?(candidate)

      changed = File.read(dest) != File.read(candidate)
      FileUtils.cp(candidate, dest)
      puts(changed ? "  updated   #{File.basename(dest)}" : "  unchanged #{File.basename(dest)}")
    end
    puts "Done. Review the diff, then run `rake generate`."
  end
end

task default: ["generate:check", :spec, :rubocop, :steep, :rbs]
