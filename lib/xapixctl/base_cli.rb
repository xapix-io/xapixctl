# frozen_string_literal: true

require 'thor'
require 'xapixctl/util'

module Xapixctl
  class BaseCli < Thor
    def self.exit_on_failure?; true; end

    def self.start(given_args = ARGV, config = {})
      super
    rescue StandardError => err
      config[:debug] || ENV["THOR_DEBUG"] == "1" ? (raise err) : config[:shell].error(err.message)
      exit(false) if exit_on_failure?
    end

    class_option :org, aliases: "-o", desc: "Organization; Fallback: environment variable XAPIX_ORG"
    class_option :project, aliases: "-p", desc: "Project, can be ORG/PROJECT; Fallback: environment variable XAPIX_PROJECT"
    class_option :debug, type: :boolean, desc: "Print details for debugging"
    class_option :xapix_url, desc: "Fallback: environment variable XAPIX_URL. URL to Xapix. Default: https://cloud.xapix.io/"
    class_option :xapix_token, desc: "Fallback: environment variable XAPIX_TOKEN. Your access token."

    private

    def exit_with_api_error(err, result)
      details = result['errors'].map { |k| k['detail'] }.unshift('').join("\n ") rescue err.to_s
      warn "API error: #{details}"
      exit 1
    end

    def show_deployment_status(result)
      return unless result && result['project_publication']
      say "deployment: #{result.dig('project_publication', 'deployment')}"
      shell.indent do
        say "data api: #{result.dig('project_publication', 'data_api')} (version: #{result.dig('project_publication', 'data_api_version').presence || 'n/a'})"
        say "user management: #{result.dig('project_publication', 'user_management')}"
        if result.dig('project_publication', 'deployment') == 'success'
          say "base URL: #{result.dig('project_publication', 'base_url')}"
        end
      end
    end

    def connection
      @connection ||= begin
        url = options[:xapix_url] || ENV['XAPIX_URL'] || 'https://cloud.xapix.io/'
        token = options[:xapix_token] || ENV['XAPIX_TOKEN']
        raise Thor::RequiredArgumentMissingError, "No XAPIX_TOKEN given. Either use --xapix_token [TOKEN] or set environment variable XAPIX_TOKEN (recommended)" if !token
        PhoenixClient.connection(
          url, token,
          default_error_handler: ->(err, result) { exit_with_api_error(err, result) },
          logging: options[:debug] ? 'stdout' : nil
        )
      end
    end

    def org_or_prj_connection
      options[:project] ? prj_connection : org_connection
    end

    def org_connection
      org = options[:org] || ENV['XAPIX_ORG']
      raise Thor::RequiredArgumentMissingError, "No organization given. Either use --org [ORG] or set environment variable XAPIX_ORG" if !org
      @org_connection ||= connection.organization(org)
    end

    def prj_connection
      project = options[:project] || ENV['XAPIX_PROJECT']
      org = options[:org] || ENV['XAPIX_ORG']
      raise Thor::RequiredArgumentMissingError, "No project given. Either use --project [ORG/PROJECT] or set environment variable XAPIX_PROJECT" if !project
      if project.include?('/')
        org, project = project.split('/', 2)
      end
      raise Thor::RequiredArgumentMissingError, "No organization given. Either use --org [ORG] or set environment variable XAPIX_ORG" if !org
      @prj_connection ||= connection.project(org: org, project: project)
    end
  end
end
