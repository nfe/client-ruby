# frozen_string_literal: true

require "fileutils"

module Nfe
  module Build
    # Maps relative generated paths to absolute paths under lib_root/sig_root,
    # writes files, and prunes stale generated files. Shared by Generator and
    # CheckMode so the path convention lives in one place.
    module FileLayout
      LIB_PREFIX = "lib/nfe/generated"
      SIG_PREFIX = "sig/nfe/generated"

      module_function

      def absolute_path(rel, lib_root, sig_root)
        if rel.start_with?("#{SIG_PREFIX}/")
          File.join(sig_root, rel.sub(%r{\Asig/}, ""))
        else
          File.join(lib_root, rel.sub(%r{\Alib/}, ""))
        end
      end

      def write_file(rel, contents, lib_root, sig_root)
        path = absolute_path(rel, lib_root, sig_root)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, contents)
        path
      end

      def prune_stale(current_rels, lib_root, sig_root)
        keep = current_rels.to_set { |rel| absolute_path(rel, lib_root, sig_root) }
        generated_dirs(lib_root, sig_root).each do |dir|
          next unless Dir.exist?(dir)

          Dir.glob(File.join(dir, "**", "*.{rb,rbs}")).each do |path|
            File.delete(path) unless keep.include?(path)
          end
        end
      end

      def generated_dirs(lib_root, sig_root)
        [File.join(lib_root, "nfe/generated"), File.join(sig_root, "nfe/generated")]
      end
    end
  end
end
