# frozen_string_literal: true

require 'json'
require 'psych'
require 'rest_client'
require 'xapixctl/phoenix_client/result_handler'
require 'xapixctl/phoenix_client/organization_connection'
require 'xapixctl/phoenix_client/project_connection'
require 'xapixctl/phoenix_client/connection'

module Xapixctl
  module PhoenixClient
    # sorting is intentional to reflect dependencies when exporting
    SUPPORTED_RESOURCE_TYPES = %w[
      Project
      Ambassador
      AuthScheme
      Credential
      Proxy
      CacheConnection
      Schema
      DataSource
      Service
      ServiceInstall
      Pipeline
      EndpointGroup
      Endpoint
      StreamGroup
      Stream
      StreamProcessor
      Scheduler
      ApiPublishing
      ApiPublishingRole
      ApiPublishingAccessRule
    ].freeze

    TEXT_FORMATTERS = {
      all: ->(data) { "id  : %<id>s\nkind: %<kind>s\nname: %<name>s\n\n" % { id: data.dig('metadata', 'id'), kind: data['kind'], name: data.dig('definition', 'name') } }
    }.freeze

    FORMATTERS = {
      json: ->(data) { JSON.pretty_generate(data) },
      yaml: ->(data) { Psych.dump(data) },
      text: ->(data) { (TEXT_FORMATTERS[data.dig('metadata', 'type')] || TEXT_FORMATTERS[:all]).call(data) }
    }.freeze

    PREVIEW_FORMATTERS = {
      json: ->(data) { JSON.pretty_generate(data) },
      yaml: ->(data) { Psych.dump(data) },
      text: ->(data) do
        preview = data['preview']
        if ['RestJson', 'SoapXml'].include?(data['content_type'])
          res = StringIO.new
          if preview.is_a?(Hash)
            res.puts "HTTP #{preview['status']}"
            preview['headers']&.each { |h, v| res.puts "#{h}: #{v}" }
            res.puts
            res.puts preview['body']
          else
            res.puts preview
          end
          res.string
        else
          Psych.dump(preview)
        end
      end
    }.freeze

    DEFAULT_SUCCESS_HANDLER = ->(result) { result }
    DEFAULT_ERROR_HANDLER = ->(err, _response) { warn "Could not get data: #{err}" }

    def self.connection(url, token, default_success_handler: DEFAULT_SUCCESS_HANDLER, default_error_handler: DEFAULT_ERROR_HANDLER, logging: nil)
      Connection.new(url, token, default_success_handler, default_error_handler, logging)
    end

    def self.supported_type?(type)
      SUPPORTED_RESOURCE_TYPES.include?(type)
    end
  end
end
