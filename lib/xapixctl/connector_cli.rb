# frozen_string_literal: true

require 'xapixctl/base_cli'

module Xapixctl
  class ConnectorCli < BaseCli
    option :schema_import, desc: "Resource id of an existing Schema import"
    desc "import SPECFILE", "Create HTTP Connectors from Swagger / OpenAPI or SOAP WSDL files"
    long_desc <<-LONGDESC
      `xapixctl connectors import SPECFILE` will create HTTP Connectors from the given Swagger / OpenAPI or SOAP WSDL file.

      Examples:
      \x5> $ xapixctl connectors import ./swagger.json -p xapix/some-project
      \x5> $ xapixctl connectors import ./swagger.json -p xapix/some-project --schema-import=existing-schema
    LONGDESC
    def import(spec_filename)
      path = Pathname.new(spec_filename)
      unless path.file? && path.readable?
        warn "Cannot read #{path}, please check file exists and is readable"
        exit 1
      end
      if options[:schema_import]
        say "uploading to update schema import '#{options[:schema_import]}': #{spec_filename}..."
        result = prj_connection.update_schema_import(options[:schema_import], spec_filename)
        say "updated #{result.dig('resource', 'kind')} #{result.dig('resource', 'id')}"
      else
        say "uploading as new import: #{spec_filename}..."
        result = prj_connection.add_schema_import(spec_filename)
        say "created #{result.dig('resource', 'kind')} #{result.dig('resource', 'id')}"
      end

      [['issues', 'import'], ['validation_issues', 'validation']].each do |key, name|
        issues = result.dig('schema_import', 'report', key)
        if issues.any?
          say "\n#{name} issues:"
          shell.indent { issues.each { |issue| say "- #{issue}" } }
        end
      end

      updated_resources = result.dig('schema_import', 'updated_resources')
      if updated_resources.any?
        say "\nconnectors:"
        shell.indent { updated_resources.each { |resource| say "- #{resource['kind']} #{resource['id']}" } }
      else
        say "\nno connectors created/updated."
      end
    end
  end
end
