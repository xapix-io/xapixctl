# frozen_string_literal: true

require 'xapixctl/base_cli'

module Xapixctl
  class Sync < BaseCli
    desc "to-dir PROJECT DIRECTORY", "Syncs resources in project to directory"
    long_desc <<-LONGDESC
      `xapixctl sync to-dir project dir` will export all resources of a given project and remove any additional resources from the directory.

      Examples:
      \x5> $ xapixctl sync to-dir xapix/some-project ./project_dir
    LONGDESC
    def to_dir(org_project, dir)
      sync_path = Pathname.new(dir)
      org, project = org_project.split('/', 2)

      res_details = connection.resource('Project', project, org: org)
      write_resource_to(res_details, sync_path, 'project')
      sync_path.join('README.md').write(generate_readme(res_details, org_project))

      (connection.resource_types_for_export - ['Project']).each do |type|
        res_path = sync_path.join(type.underscore)
        new_files = []
        connection.resource_ids(type, org: org, project: project).each do |res_id|
          res_details = connection.resource(type, res_id, org: org, project: project)
          new_files << write_resource_to(res_details, res_path, res_id)
        end
        (res_path.glob('*.yaml') - new_files).each do |outdated_file|
          outdated_file.delete
          puts "removed #{outdated_file}"
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

    def generate_readme(res_details, org_project)
      <<~EOREADME
        # #{res_details.dig('definition', 'name')}
        #{res_details.dig('definition', 'description')}

        Project exported from #{File.join(ENV['XAPIX_URL'], org_project)} by xapixctl v#{Xapixctl::VERSION}.
      EOREADME
    end
  end
end
