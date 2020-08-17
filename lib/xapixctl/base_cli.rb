# frozen_string_literal: true

require 'thor'

module Xapixctl
  class BaseCli < Thor
    def self.exit_on_failure?; true; end

    class_option :verbose, type: :boolean, aliases: "-v"
    class_option :xapix_url, desc: "Fallback: environment variable XAPIX_URL. URL to Xapix. Default: https://cloud.xapix.io/"
    class_option :xapix_token, desc: "Fallback: environment variable XAPIX_TOKEN. Your access token."

    private

    def warn_api_error(text, err, result)
      details = "\n " + result['errors'].map { |k| k['detail'] }.join("\n ") rescue err.to_s
      warn "#{text}: #{details}"
      exit 1
    end

    def show_deployment_status(result)
      return unless result && result['project_publication']
      puts "deployment: #{result.dig('project_publication', 'deployment')}"
      puts " data api: #{result.dig('project_publication', 'data_api')} (version: #{result.dig('project_publication', 'data_api_version').presence || 'n/a'})"
      puts " user management: #{result.dig('project_publication', 'user_management')}"
      if result.dig('project_publication', 'deployment') == 'success'
        puts " base URL: #{result.dig('project_publication', 'base_url')}"
      end
    end

    DOCUMENT_STRUCTURE = %w[version kind metadata definition].freeze
    def resources_from_file(filename)
      yaml_string = filename == '-' ? $stdin.read : IO.read(filename)
      yaml_string.split(/^---\s*\n/).map { |yml| Psych.safe_load(yml) }.compact.each do |doc|
        unless (DOCUMENT_STRUCTURE - doc.keys.map(&:to_s)).empty?
          warn "does not look like a correct resource definition:"
          warn doc.inspect
          exit 1
        end
        yield doc
      end
    end

    def connection
      url = options[:xapix_url] || ENV['XAPIX_URL'] || 'https://cloud.xapix.io/'
      token = options[:xapix_token] || ENV['XAPIX_TOKEN']
      raise Thor::RequiredArgumentMissingError, "no XAPIX_TOKEN given. Either use --xapix_token [TOKEN] or set environment variable XAPIX_TOKEN (recommended)" if !token
      PhoenixClient::Connection.new(url, token)
    end
  end
end