# frozen_string_literal: true

require 'pathname'

module Xapixctl
  module Util
    extend self

    class InvalidDocumentStructureError < StandardError
      def initialize(file)
        super("#{file} has invalid document structure")
      end
    end

    DOCUMENT_STRUCTURE = %w[version kind metadata definition].freeze

    def resources_from_file(filename, ignore_missing: false)
      load_files(filename, ignore_missing) do |actual_file, yaml_string|
        yaml_string.split(/^---\s*\n/).map { |yml| Psych.safe_load(yml) }.compact.each do |doc|
          raise InvalidDocumentStructureError, actual_file unless (DOCUMENT_STRUCTURE - doc.keys.map(&:to_s)).empty?
          yield doc
        end
      end
    end

    def load_files(filename, ignore_missing)
      if filename == '-'
        yield 'STDIN', $stdin.read
      else
        pn = filename.is_a?(Pathname) ? filename : Pathname.new(filename)
        if pn.directory?
          pn.glob(["**/*.yaml", "**/*.yml"]).sort.each { |dpn| yield dpn.to_s, dpn.read }
        elsif pn.exist?
          yield pn.to_s, pn.read
        elsif !ignore_missing
          warn "file not found: #{filename}"
          exit 1
        end
      end
    end
  end
end
