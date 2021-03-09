# frozen_string_literal: true

require 'xapixctl/base_cli'
require 'xapixctl/preview_cli'

module Xapixctl
  class Cli < BaseCli
    desc "preview SUBCOMMAND ...ARGS", "Request preview for resources"
    subcommand "preview", Preview

    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project"
    option :format, aliases: "-f", default: 'text', enum: ['text', 'yaml', 'json'], desc: "Output format"
    desc "get TYPE [ID]", "retrieve either all resources of given TYPE or just the resource of given TYPE and ID"
    long_desc <<-LONGDESC
      `xapixctl get TYPE` will retrieve the list of all resources of given type.

      If requested on an organization (i.e. no project given), the following types are available:
      \x5 Project

      If requested on an a project (i.e. organization and project are given), the following types are available:
      \x5 Ambassador, AuthScheme, CacheConnection, Credential, DataSource, Endpoint, EndpointGroup, Proxy, Schema, Stream, StreamGroup

      Use the format to switch between the different output formats.

      Examples:
      \x5> $ xapixctl get -o xapix Project
      \x5> $ xapixctl get -o xapix Project some-project
      \x5> $ xapixctl get -o xapix -p some-project DataSource
      \x5> $ xapixctl get -o xapix -p some-project DataSource get-a-list
    LONGDESC
    def get(resource_type, resource_id = nil)
      if resource_id
        puts connection.resource(resource_type, resource_id, org: options[:org], project: options[:project], format: options[:format].to_sym)
      else
        connection.resource_ids(resource_type, org: options[:org], project: options[:project]).each do |res_id|
          get(resource_type, res_id)
        end
      end
    end

    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project", required: true
    option :format, aliases: "-f", default: 'text', enum: ['text', 'yaml', 'json'], desc: "Output format"
    desc "export", "retrieves all resources within a project"
    long_desc <<-LONGDESC
      `xapixctl export` will retrieve the list of all resources of given type.

      Use the format to switch between the different output formats.

      Examples:
      \x5> $ xapixctl export -o xapix -p some-project
      \x5> $ xapixctl export -o xapix -p some-project -f yaml > some_project.yaml
    LONGDESC
    def export
      get('Project', options[:project])
      (connection.resource_types_for_export - ['Project']).each { |type| get(type) }
    end

    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project"
    option :file, aliases: "-f", required: true
    desc "apply", "Create or update a resource from a file"
    long_desc <<-LONGDESC
      `xapixctl apply -f FILE` will apply the given resource description.

      If applied on an organization (i.e. no project given), the project is taken from the resource description.

      If applied on a project (i.e. organization and project are given), the given project is used.

      The given file should be in YAML format and can contain multiple resource definitions, each as it's own YAML document.
      You can also provide a directory, in which case all files with yml/yaml extension will get loaded.
      You can also read from stdin by using '-'.

      Examples:
      \x5> $ xapixctl apply -o xapix -f get_a_list.yaml
      \x5> $ xapixctl apply -o xapix -p some-project -f get_a_list.yaml
      \x5> $ xapixctl apply -o xapix -p some-project -f ./

      To copy over all data sources from one project to another:
      \x5> $ xapixctl get -o xapix-old -p some-project DataSource -f yaml | xapixctl apply -o xapix-new -f -
    LONGDESC
    def apply
      resources_from_file(options[:file]) do |desc|
        puts "applying #{desc['kind']} #{desc.dig('metadata', 'id')}"
        connection.apply(desc, org: options[:org], project: options[:project])
        puts "OK"
      end
    end

    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project"
    option :file, aliases: "-f"
    desc "delete [TYPE ID] [-f FILE]", "delete the resources in the file"
    long_desc <<-LONGDESC
      `xapixctl delete -f FILE` will delete all the resources listed in the file.
      \x5`xapixctl delete TYPE ID` will delete the resource by given TYPE and ID.

      The given file should be in YAML format and can contain multiple resource definitions, each as it's own YAML document.
      You can also provide a directory, in which case all files with yml/yaml extension will get loaded.
      You can also read from stdin by using '-'.

      Examples:
      \x5> $ xapixctl delete -o xapix -p some-project -f get_a_list.yaml
      \x5> $ xapixctl delete -o xapix -p some-project -f ./
      \x5> $ xapixctl delete -o xapix -p some-project DataSource get-a-list
      \x5> $ xapixctl delete -o xapix Project some-project
    LONGDESC
    def delete(resource_type = nil, resource_id = nil)
      if resource_type && resource_id
        connection.delete(resource_type, resource_id, org: options[:org], project: options[:project])
        puts "DELETED #{resource_type} #{resource_id}"
      elsif options[:file]
        resources_from_file(options[:file]) do |desc|
          res_type = desc['kind']
          res_id = desc.dig('metadata', 'id')
          puts "deleting #{res_type} #{res_id}"
          delete(res_type, res_id)
        end
      else
        warn "need TYPE and ID or --file option"
      end
    end

    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project", required: true
    desc "publish", "Publishes the current version of the given project"
    long_desc <<-LONGDESC
      `xapixctl publish` will publish the given project.

      Examples:
      \x5> $ xapixctl publish -o xapix -p some-project
    LONGDESC
    def publish
      connection.publish(org: options[:org], project: options[:project]) do |res|
        res.on_success { |result| show_deployment_status(result) }
        res.on_error { |err, result| show_deployment_status(result); exit_with_api_error(err, result) }
      end
    end

    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project", required: true
    desc "logs CORRELATION_ID", "Retrieves the execution logs for the given correlation ID"
    long_desc <<-LONGDESC
      `xapixctl logs CORRELATION_ID` will retrieve execution logs for the given correlation ID.

      The correlation ID is included as X-Correlation-Id header in the response of each request.

      Examples:
      \x5> $ xapixctl logs be9c8608-e291-460d-bc20-5a394c4079d4 -o xapix -p some-project
    LONGDESC
    def logs(correlation_id)
      result = connection.logs(correlation_id, org: options[:org], project: options[:project])
      puts result['logs'].to_yaml
    end

    SUPPORTED_CONTEXTS = ['Project', 'Organization'].freeze
    desc "api-resources", "retrieves a list of all available resource types"
    def api_resources
      available_types = connection.available_resource_types
          format_str = "%20.20s %20.20s"
          puts format_str % ['Type', 'Required Context']
          available_types.sort_by { |desc| desc['type'] }.each do |desc|
            next unless SUPPORTED_CONTEXTS.include?(desc['context'])
            puts format_str % [desc['type'], desc['context']]
          end
        end
  end
end
