# frozen_string_literal: true

require 'thor'

module Xapixctl
  class BaseCli < Thor
    def self.exit_on_failure?; true; end

    class_option :verbose, type: :boolean, aliases: "-v"
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
      puts "deployment: #{result.dig('project_publication', 'deployment')}"
      puts " data api: #{result.dig('project_publication', 'data_api')} (version: #{result.dig('project_publication', 'data_api_version').presence || 'n/a'})"
      puts " user management: #{result.dig('project_publication', 'user_management')}"
      if result.dig('project_publication', 'deployment') == 'success'
        puts " base URL: #{result.dig('project_publication', 'base_url')}"
      end
    end

    DOCUMENT_STRUCTURE = %w[version kind metadata definition].freeze
    def resources_from_file(filename)
      load_files(filename) do |yaml_string|
        yaml_string.split(/^---\s*\n/).map { |yml| Psych.safe_load(yml) }.compact.each do |doc|
          unless (DOCUMENT_STRUCTURE - doc.keys.map(&:to_s)).empty?
            warn "does not look like a correct resource definition:"
            warn doc.inspect
            exit 1
          end
          yield doc
        end
      end
    end

    def load_files(filename)
      if filename == '-'
        yield $stdin.read
      else
        pn = Pathname.new(filename)
        if pn.directory?
          pn.glob(["**/*.yaml", "**/*.yml"]).sort.each { |dpn| yield dpn.read }
        else
          yield pn.read
        end
      end
    end

    def connection
      @connection ||= begin
        url = options[:xapix_url] || ENV['XAPIX_URL'] || 'https://cloud.xapix.io/'
        token = options[:xapix_token] || ENV['XAPIX_TOKEN']
        raise Thor::RequiredArgumentMissingError, "no XAPIX_TOKEN given. Either use --xapix_token [TOKEN] or set environment variable XAPIX_TOKEN (recommended)" if !token
        PhoenixClient::Connection.new(
          url, token,
          default_error_handler: ->(err, result) { exit_with_api_error(err, result) })
      end
    end
  end
end
