# frozen_string_literal: true

module Xapixctl
  module PhoenixClient

    class ResultHandler
      def initialize
        @success_handler = ->(result) { result }
        @error_handler = ->(err, _response) { warn "Could not get data: #{err}" }
        @result_handler = nil
        yield self if block_given?
      end

      def on_success(&block); @success_handler = block; self; end

      def on_error(&block); @error_handler = block; self; end

      def prepare_data(proc); @result_handler = proc; self; end

      def formatter(proc); @formatter = proc; self; end

      def run
        res = yield
        res = res.present? ? JSON.parse(res) : res
        res = @result_handler ? @result_handler.call(res) : res
        res = @formatter ? @formatter.call(res) : res
        @success_handler.call(res)
      rescue RestClient::Exception => err
        response = JSON.parse(err.response) rescue {}
        @error_handler.call(err, response)
      rescue SocketError, Errno::ECONNREFUSED => err
        @error_handler.call(err, nil)
      end
    end

    TEXT_FORMATTERS = {
      all: ->(data) { "id  : %{id}\nkind: %{kind}\nname: %{name}\n\n" % { id: data.dig('metadata', 'id'), kind: data.dig('kind'), name: data.dig('definition', 'name') } }
    }.freeze

    FORMATTERS = {
      json: ->(data) { JSON.pretty_generate(data) },
      yaml: ->(data) { Psych.dump(data.deep_transform_keys! { |k| k.to_s.camelize(:lower) }) },
      text: ->(data) { (TEXT_FORMATTERS[data.dig('metadata', 'type')] || TEXT_FORMATTERS[:all]).call(data) }
    }.freeze

    class Connection
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
        Pipeline
        EndpointGroup
        Endpoint
        StreamGroup
        Stream
        ApiPublishing
        ApiPublishingRole
      ].freeze

      def initialize(url, token)
        @client = RestClient::Resource.new(File.join(url, 'api/v1'), verify_ssl: false, accept: :json, content_type: :json, headers: { Authorization: "Bearer #{token}" })
      end

      def resource(resource_type, resource_id, org:, project: nil, format: :hash, &block)
        ResultHandler.new(&block).
          formatter(FORMATTERS[format]).
          run { @client[resource_path(org, project, resource_type, resource_id)].get }
      end

      def resource_ids(resource_type, org:, project: nil, &block)
        ResultHandler.new(&block).
          prepare_data(->(data) { data['resource_ids'] }).
          run { @client[resources_path(org, project, resource_type)].get }
      end

      def apply(resource_description, org:, project: nil, &block)
        ResultHandler.new(&block).
          run { @client[generic_resource_path(org, project)].put(resource_description.to_json) }
      end

      def delete(resource_type, resource_id, org:, project: nil, &block)
        ResultHandler.new(&block).
          run { @client[resource_path(org, project, resource_type, resource_id)].delete }
      end

      def publish(org:, project:, &block)
        ResultHandler.new(&block).
          run { @client[project_publications_path(org, project)].post('') }
      end

      def available_resource_types(&block)
        ResultHandler.new(&block).
          prepare_data(->(data) { data['resource_types'] }).
          run { @client[resource_types_path].get }
      end

      def resource_types_for_export
        @resource_types_for_export ||=
          available_resource_types do |res|
            res.on_success { |available_types| SUPPORTED_RESOURCE_TYPES & available_types.map { |desc| desc['type'] } }
            res.on_error { |err, _response| raise err }
          end
      end

      private

      def resource_path(org, project, type, id)
        type = translate_type(type)
        project ? "/projects/#{org}/#{project}/#{type}/#{id}" : "/orgs/#{org}/#{type}/#{id}"
      end

      def resources_path(org, project, type)
        type = translate_type(type)
        project ? "/projects/#{org}/#{project}/#{type}" : "/orgs/#{org}/#{type}"
      end

      def generic_resource_path(org, project)
        project ? "projects/#{org}/#{project}/resource" : "orgs/#{org}/resource"
      end

      def project_publications_path(org, project)
        "/projects/#{org}/#{project}/publications"
      end

      def resource_types_path
        "/resource_types"
      end

      def translate_type(resource_type)
        return 'ApiPublishingRole' if resource_type == 'ApiPublishing/Role'
        resource_type.sub(%r[/.*], '') # cut off everything after first slash
      end
    end
  end
end
