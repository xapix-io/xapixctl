# frozen_string_literal: true

require 'xapixctl/base_cli'
require 'pathname'

module Xapixctl
  class SyncCli < BaseCli
    class_option :credentials, desc: "Whether to include Credential resources in sync", type: :boolean, default: true
    class_option :exclude_types, desc: "Resource types to exclude from sync", type: :array

    desc "to-dir DIRECTORY", "Syncs resources in project to directory"
    long_desc <<-LONGDESC
      `xapixctl sync to-dir DIRECTORY` will export all resources of a given project and remove any additional resources from the directory.

      With --no-credentials you can exclude all credentials from getting exported.

      With --exclude-types you can specify any resource types besides Project you'd like to exclude.

      When excluding types, the excluded types will be recorded in the sync directory in a file called .excluded_types, so that any future syncs will exclude those types.

      Examples:
      \x5> $ xapixctl sync to-dir ./project_dir -p xapix/some-project
      \x5> $ xapixctl sync to-dir ./project_dir -p xapix/some-project --no-credentials
      \x5> $ xapixctl sync to-dir ./project_dir -p xapix/some-project --exclude-types=ApiPublishing ApiPublishingRole Credential
    LONGDESC
    def to_dir(dir)
      sync_path = SyncPath.new(dir, prj_connection.resource_types_for_export, excluded_types)

      res_details = prj_connection.project_resource
      sync_path.write_file(generate_readme(res_details), 'README.md')
      sync_path.write_resource_yaml(res_details, 'project')

      sync_path.types_to_sync.each do |type|
        res_path = sync_path.resource_path(type)
        prj_connection.resource_ids(type).each do |res_id|
          res_details = prj_connection.resource(type, res_id)
          res_path.write_resource_yaml(res_details, res_id)
        end
        res_path.remove_outdated_resources
      end
      sync_path.update_excluded_types_file
    end

    desc "from-dir DIRECTORY", "Syncs resources in project from directory"
    long_desc <<-LONGDESC
      `xapixctl sync from-dir project dir` will import all resources into the given project from the directory and remove any additional resources which are not present in the directory.

      With --no-credentials you can exclude all credentials from getting exported.

      With --exclude-types you can specify any resource types besides Project you'd like to exclude.

      Examples:
      \x5> $ xapixctl sync from-dir ./project_dir -p xapix/some-project
      \x5> $ xapixctl sync from-dir ./project_dir -p xapix/some-project --no-credentials
      \x5> $ xapixctl sync from-dir ./project_dir -p xapix/some-project --exclude-types=ApiPublishing ApiPublishingRole Credential
    LONGDESC
    def from_dir(dir)
      sync_path = SyncPath.new(dir, prj_connection.resource_types_for_export, excluded_types)

      sync_path.load_resource('project') do |desc|
        puts "applying #{desc['kind']} #{desc.dig('metadata', 'id')} to #{prj_connection.project}"
        desc['metadata']['id'] = prj_connection.project
        prj_connection.organization.apply(desc)
      end

      outdated_resources = {}
      sync_path.types_to_sync.each do |type|
        res_path = sync_path.resource_path(type)
        updated_resource_ids = []
        res_path.load_resources do |desc|
          puts "applying #{desc['kind']} #{desc.dig('metadata', 'id')}"
          updated_resource_ids += prj_connection.apply(desc)
        end
        outdated_resources[type] = prj_connection.resource_ids(type) - updated_resource_ids
      end

      outdated_resources.each do |type, resource_ids|
        resource_ids.each do |resource_id|
          puts "removing #{type} #{resource_id}"
          prj_connection.delete(type, resource_id)
        end
      end
    end

    private

    class ResourcePath
      def initialize(path)
        @path = path
        @resource_files = []
      end

      def write_file(content, filename)
        @path.mkpath
        unless @path.directory? && @path.writable?
          warn "Cannot write to #{@path}, please check directory exists and is writable"
          exit 1
        end
        file = @path.join(filename)
        file.write(content)
        puts "updated #{file}..."
        file
      end

      def write_resource_yaml(res_details, res_name)
        file = write_file(res_details.to_yaml, "#{res_name}.yaml")
        @resource_files << file
        file
      end

      def load_resources(&block)
        Util.resources_from_file(@path, ignore_missing: true, &block)
      end

      def load_resource(res_name, &block)
        Util.resources_from_file(@path.join("#{res_name}.yaml"), ignore_missing: false, &block)
      end

      def remove_outdated_resources
        (@path.glob('*.yaml') - @resource_files).each do |outdated_file|
          outdated_file.delete
          puts "removed #{outdated_file}"
        end
      end
    end

    class SyncPath < ResourcePath
      attr_reader :types_to_sync

      def initialize(dir, all_types, excluded_types)
        super(Pathname.new(dir))
        @all_types = all_types
        @excluded_types_file = @path.join('.excluded_types')
        @excluded_types = excluded_types || []
        @excluded_types += @excluded_types_file.read.split if @excluded_types_file.exist?
        @excluded_types &= @all_types
        @excluded_types.sort!
        @types_to_sync = @all_types - @excluded_types
        puts "Resource types excluded from sync: #{@excluded_types.join(', ')}" if @excluded_types.any?
      end

      def resource_path(type)
        ResourcePath.new(@path.join(type.underscore))
      end

      def update_excluded_types_file
        @excluded_types_file.write(@excluded_types.join(" ") + "\n") if @excluded_types.any?
      end
    end

    def excluded_types
      excluded = options[:exclude_types]
      excluded += ['Credential'] unless options[:credentials]
      excluded
    end

    def generate_readme(res_details)
      <<~EOREADME
        # #{res_details.dig('definition', 'name')}
        #{res_details.dig('definition', 'description')}

        Project exported from #{File.join(prj_connection.public_project_url)} by xapixctl v#{Xapixctl::VERSION}.
      EOREADME
    end
  end
end
