# frozen_string_literal: true

module Xapixctl
  module PhoenixClient
    class Connection
      DEFAULT_CLIENT_OPTS = { verify_ssl: false, headers: { accept: :json } }.freeze

      attr_reader :xapix_url, :client

      def initialize(url, token, default_success_handler, default_error_handler, logging)
        @xapix_url = url
        client_opts = DEFAULT_CLIENT_OPTS.deep_merge(headers: { Authorization: "Bearer #{token}" })
        client_opts.merge!(log: RestClient.create_log(logging)) if logging
        @client = RestClient::Resource.new(File.join(url, 'api/v1'), client_opts)
        @default_success_handler = default_success_handler
        @default_error_handler = default_error_handler
      end

      def on_success(&block); @default_success_handler = block; self; end

      def on_error(&block); @default_error_handler = block; self; end

      def available_resource_types(&block)
        @available_resource_types ||= begin
          result_handler(block).
            prepare_data(->(data) { data['resource_types'].freeze }).
            run { @client[resource_types_path].get }
        end
      end

      def organization(org)
        OrganizationConnection.new(self, org)
      end

      def project(org:, project:)
        ProjectConnection.new(self, org, project)
      end

      def result_handler(block)
        ResultHandler.new(default_success_handler: @default_success_handler, default_error_handler: @default_error_handler, &block)
      end

      private

      def resource_types_path
        "/resource_types"
      end
    end
  end
end
