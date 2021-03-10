# frozen_string_literal: true

require 'xapixctl/base_cli'

module Xapixctl
  class Sync < BaseCli
    option :org, aliases: "-o", desc: "Organization"
    option :project, aliases: "-p", desc: "Project"
    desc "to-dir DIRECTORY", "Syncs resources in project to directory"
    long_desc <<-LONGDESC
      `xapixctl sync to-dir project dir` will export all resources of a given project and remove any additional resources from the directory.

      Examples:
      \x5> $ xapixctl sync to-dir xapix/some-project ./project_dir
    LONGDESC
    def to_dir(dir)
      sync_path = Pathname.new(dir)

      res_details = prj_connection.project_resource
      write_resource_to(res_details, sync_path, 'project')
      sync_path.join('README.md').write(generate_readme(res_details))

      prj_connection.resource_types_for_export.each do |type|
        res_path = sync_path.join(type.underscore)
        new_files = []
        prj_connection.resource_ids(type).each do |res_id|
          res_details = prj_connection.resource(type, res_id)
          new_files << write_resource_to(res_details, res_path, res_id)
        end
        (res_path.glob('*.yaml') - new_files).each do |outdated_file|
          outdated_file.delete
          puts "removed #{outdated_file}"
        end
      end
    end

    option :org, aliases: "-o", desc: "Organization"
    option :project, aliases: "-p", desc: "Project"
    desc "from-dir DIRECTORY", "Syncs resources in project from directory"
    long_desc <<-LONGDESC
      `xapixctl sync from-dir project dir` will import all resources into the given project from the directory and remove any additional resources which are not present in the directory.

      Examples:
      \x5> $ xapixctl sync from-dir xapix/some-project ./project_dir
    LONGDESC
    def from_dir(dir)
      sync_path = Pathname.new(dir)

      resources_from_file(sync_path.join('project.yaml'), ignore_missing: false) do |desc|
        puts "applying #{desc['kind']} #{desc.dig('metadata', 'id')} to #{prj_connection.project}"
        desc['metadata']['id'] = prj_connection.project
        prj_connection.organization.apply(desc)
      end

      outdated_resources = {}
      prj_connection.resource_types_for_export.each do |type|
        res_path = sync_path.join(type.underscore)
        updated_resource_ids = []
        resources_from_file(res_path, ignore_missing: true) do |desc|
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

    def write_resource_to(res_details, res_path, res_name)
      res_path.mkpath
      unless res_path.directory? && res_path.writable?
        warn "Cannot write to #{dir}, please check directory exists and is writable"
        exit 1
      end
      res_file = res_path.join("#{res_name}.yaml")
      res_file.write(res_details.to_yaml)
      puts "updated #{res_file}..."
      res_file
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
