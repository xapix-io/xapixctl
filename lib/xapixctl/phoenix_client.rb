# frozen_string_literal: true

module Xapixctl
  module PhoenixClient
    class ResultHandler
      def initialize(default_success_handler:, default_error_handler:)
        @success_handler = default_success_handler
        @error_handler = default_error_handler
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

    class Connection
      DEFAULT_SUCCESS_HANDLER = ->(result) { result }
      DEFAULT_ERROR_HANDLER = ->(err, _response) { warn "Could not get data: #{err}" }

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
        Service
        ServiceInstall
        EndpointGroup
        Endpoint
        StreamGroup
        Stream
        StreamProcessor
        Scheduler
        ApiPublishing
        ApiPublishingRole
      ].freeze

      def initialize(url, token, default_success_handler: DEFAULT_SUCCESS_HANDLER, default_error_handler: DEFAULT_ERROR_HANDLER)
        @client = RestClient::Resource.new(File.join(url, 'api/v1'), verify_ssl: false, accept: :json, content_type: :json, headers: { Authorization: "Bearer #{token}" })
        @default_success_handler = default_success_handler
        @default_error_handler = default_error_handler
      end

      def on_success(&block); @default_success_handler = block; self; end

      def on_error(&block); @default_error_handler = block; self; end

      def resource(resource_type, resource_id, org:, project: nil, format: :hash, &block)
        result_handler(block).
          formatter(FORMATTERS[format]).
          run { @client[resource_path(org, project, resource_type, resource_id)].get }
      end

      def resource_ids(resource_type, org:, project: nil, &block)
        result_handler(block).
          prepare_data(->(data) { data['resource_ids'] }).
          run { @client[resources_path(org, project, resource_type)].get }
      end

      def apply(resource_description, org:, project: nil, &block)
        result_handler(block).
          run { @client[generic_resource_path(org, project)].put(resource_description.to_json) }
      end

      def delete(resource_type, resource_id, org:, project: nil, &block)
        result_handler(block).
          run { @client[resource_path(org, project, resource_type, resource_id)].delete }
      end

      def pipeline_preview(pipeline_id, org:, project:, format: :hash, &block)
        result_handler(block).
          prepare_data(->(data) { data['pipeline_preview'] }).
          formatter(PREVIEW_FORMATTERS[format]).
          run { @client[pipeline_preview_path(org, project, pipeline_id)].get }
      end

      def endpoint_preview(endpoint_id, org:, project:, format: :hash, &block)
        result_handler(block).
          prepare_data(->(data) { data['endpoint_preview'] }).
          formatter(PREVIEW_FORMATTERS[format]).
          run { @client[endpoint_preview_path(org, project, endpoint_id)].get }
      end

      def stream_processor_preview(stream_processor_id, org:, project:, format: :hash, &block)
        result_handler(block).
          prepare_data(->(data) { data['stream_processor_preview'] }).
          formatter(PREVIEW_FORMATTERS[format]).
          run { @client[stream_processor_preview_path(org, project, stream_processor_id)].get }
      end

      def publish(org:, project:, &block)
        result_handler(block).
          run { @client[project_publications_path(org, project)].post('') }
      end

      def logs(correlation_id, org:, project:, &block)
        result_handler(block).
          run { @client[project_logss_path(org, project, correlation_id)].get }
      end

      def available_resource_types(&block)
        result_handler(block).
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

      def onboarding(org:, project:)
        OnboardingConnection.new(@client, @default_success_handler, @default_error_handler, org, project)
      end

      private

      def result_handler(block)
        ResultHandler.new(default_success_handler: @default_success_handler, default_error_handler: @default_error_handler, &block)
      end

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

      def pipeline_preview_path(org, project, pipeline)
        "/projects/#{org}/#{project}/pipelines/#{pipeline}/preview"
      end

      def endpoint_preview_path(org, project, endpoint)
        "/projects/#{org}/#{project}/endpoints/#{endpoint}/preview"
      end

      def stream_processor_preview_path(org, project, stream_processor)
        "/projects/#{org}/#{project}/stream_processors/#{stream_processor}/preview"
      end

      def project_publications_path(org, project)
        "/projects/#{org}/#{project}/publications"
      end

      def project_logss_path(org, project, correlation_id)
        "/projects/#{org}/#{project}/logs/#{correlation_id}"
      end

      def resource_types_path
        "/resource_types"
      end

      def translate_type(resource_type)
        return 'ApiPublishingRole' if resource_type == 'ApiPublishing/Role'
        resource_type.sub(%r[/.*], '') # cut off everything after first slash
      end
    end

    class OnboardingConnection
      def initialize(client, default_success_handler, default_error_handler, org, project)
        @client = client
        @default_success_handler = default_success_handler
        @default_error_handler = default_error_handler
        @org = org
        @project = project
      end

      # Notes on parameters:
      # - Query parameters should be part of the URL
      # - Path parameters should be marked with `{name}` in the URL, and values should be given in path_params hash
      # - Headers should be given in headers hash
      # - Cookies should be given in cookies hash
      # - The body has to be given as a string
      # - The required authentication schemes should be listed, referring to previously created schemes
      #
      # This returns a hash like the following:
      #   "data_source" => { "id" => id, "resource_description" => resource_description }
      #
      # To successfully onboard a DB using the API, the following steps are needed:
      #  1. setup the data source using add_rest_data_source.
      #  2. retrieve a preview using preview_data_source using the id returned by previous step
      #  3. confirm preview
      #  4. call accept_data_source_preview to complete onboarding
      #
      def add_rest_data_source(http_method:, url:, path_params: {}, headers: {}, cookies: {}, body: nil, auth_schemes: [], &block)
        data_source_details = {
          http_method: http_method, url: url,
          parameters: { path: path_params.to_query, header: headers.to_query, cookies: cookies.to_query, body: body },
          auth_schemes: auth_schemes
        }
        result_handler(block).
          run { @client[rest_data_source_path].post(data_source: data_source_details) }
      end

      # Notes on parameters:
      # - To call a data source which requires authentication, provide a hash with each required auth scheme as key and
      #   as the value a reference to a previously created credential.
      #   Example: { scheme_ref1 => credential_ref1, scheme_ref2 => credential_ref2 }
      #
      # This returns a hashified preview like the following:
      #   { "preview" => {
      #       "sample" => { "status" => integer, "body" => { ... }, "headers" => { ... }, "cookies" => { ... } },
      #       "fetched_at" => Timestamp },
      #     "data_source" => { "id" => id, "resource_description" => resource_description } }
      #
      def preview_data_source(data_source_id, authentications: {}, &block)
        preview_data = {
          authentications: authentications.map { |scheme, cred| { auth_scheme_id: scheme, auth_credential_id: cred } }
        }
        result_handler(block).
          run { @client[data_source_preview_path(data_source_id)].post(preview_data) }
      end

      # This returns a hashified preview like the following:

      def accept_data_source_preview(data_source_id, &block)
        result_handler(block).
          run { @client[data_source_preview_path(data_source_id)].patch('') }
      end

      private

      def result_handler(block)
        ResultHandler.new(default_success_handler: @default_success_handler, default_error_handler: @default_error_handler, &block)
      end

      def rest_data_source_path
        "/projects/#{@org}/#{@project}/onboarding/data_sources/rest"
      end

      def data_source_preview_path(id)
        "/projects/#{@org}/#{@project}/onboarding/data_sources/#{id}/preview"
      end
    end
  end
end
