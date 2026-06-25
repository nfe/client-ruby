# frozen_string_literal: true

require_relative "file_layout"

module Nfe
  module Build
    # Compares the generator's in-memory output against checked-in files in
    # both lib_root and sig_root. ok only when nothing is added/removed/changed.
    module CheckMode
      module_function

      GENERATED_AT = /^\s*generated_at:\s*.*$/

      def diff(generator:, lib_root:, sig_root:)
        expected = generator.generate
        rels = (expected.keys + disk_rels(lib_root, sig_root)).uniq
        on_disk = read_disk(rels, lib_root, sig_root)

        added = (expected.keys - on_disk.keys).sort
        removed = (on_disk.keys - expected.keys).sort
        changed = changed_files(expected, on_disk)

        { ok: added.empty? && removed.empty? && changed.empty?, added: added, removed: removed, changed: changed }
      end

      # Relative paths (lib/.. or sig/..) of every committed generated file, so
      # files on disk that the generator no longer emits surface as "removed".
      def disk_rels(lib_root, sig_root)
        rels = []
        rels << "#{FileLayout::LIB_PREFIX}.rb"
        FileLayout.generated_dirs(lib_root, sig_root).each do |dir|
          root = dir.start_with?(sig_root) ? sig_root : lib_root
          prefix = dir.start_with?(sig_root) ? "sig" : "lib"
          Dir.glob(File.join(dir, "**", "*.{rb,rbs}")).each do |path|
            rels << "#{prefix}/#{path.delete_prefix("#{root}/")}"
          end
        end
        rels
      end

      def read_disk(rels, lib_root, sig_root)
        result = {}
        rels.each do |rel|
          path = FileLayout.absolute_path(rel, lib_root, sig_root)
          result[rel] = File.read(path) if File.exist?(path)
        end
        result
      end

      def changed_files(expected, on_disk)
        (expected.keys & on_disk.keys).reject do |rel|
          normalize(rel, expected[rel]) == normalize(rel, on_disk[rel])
        end.sort
      end

      # The marker's generated_at line is normalized so it never causes drift.
      def normalize(rel, contents)
        return contents unless rel.end_with?("generated_marker.rb")

        contents.gsub(GENERATED_AT, "      generated_at: nil,")
      end
    end
  end
end
