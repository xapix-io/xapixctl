# frozen_string_literal: true

module Xapixctl
  module PhoenixClient
    class ProjectConnection < OrganizationConnection
      attr_reader :project

      def initialize(connection, org, project)
        super(connection, org)
        @project = project
      end

      def project_resource(format: :hash, &block)
        organization.resource('Project', @project, format: format, &block)
      end

      def organization
        OrganizationConnection.new(@connection, @org)
      end

      def resource_types_for_export
        @resource_types_for_export ||=
          @connection.available_resource_types do |res|
            res.on_success do |available_types|
              prj_types = available_types.select { |desc| desc['context'] == 'Project' }
              SUPPORTED_RESOURCE_TYPES & prj_types.map { |desc| desc['type'] }
            end
          end
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
          data_source: {
            http_method: http_method, url: url,
            parameters: { path: path_params.to_query, header: headers.to_query, cookies: cookies.to_query, body: body },
            auth_schemes: auth_schemes
          }
        }
        result_handler(block).
          run { @client[rest_data_source_path].post(data_source_details.to_json, content_type: :json) }
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
      def data_source_preview(data_source_id, authentications: {}, &block)
        preview_data = {
          authentications: authentications.map { |scheme, cred| { auth_scheme_id: scheme, auth_credential_id: cred } }
        }
        result_handler(block).
          run { @client[data_source_preview_path(data_source_id)].post(preview_data.to_json, content_type: :json) }
      end

      def pipeline_preview(pipeline_id, format: :hash, &block)
        result_handler(block).
          prepare_data(->(data) { data['pipeline_preview'] }).
          formatter(PREVIEW_FORMATTERS[format]).
          run { @client[pipeline_preview_path(pipeline_id)].get }
      end

      def endpoint_preview(endpoint_id, format: :hash, &block)
        result_handler(block).
          prepare_data(->(data) { data['endpoint_preview'] }).
          formatter(PREVIEW_FORMATTERS[format]).
          run { @client[endpoint_preview_path(endpoint_id)].get }
      end

      def stream_processor_preview(stream_processor_id, format: :hash, &block)
        result_handler(block).
          prepare_data(->(data) { data['stream_processor_preview'] }).
          formatter(PREVIEW_FORMATTERS[format]).
          run { @client[stream_processor_preview_path(stream_processor_id)].get }
      end

      def publish(&block)
        result_handler(block).
          run { @client[project_publications_path].post('') }
      end

      def logs(correlation_id, &block)
        result_handler(block).
          run { @client[project_logss_path(correlation_id)].get }
      end

      # This returns a hashified preview like the following:

      def accept_data_source_preview(data_source_id, &block)
        result_handler(block).
          run { @client[data_source_preview_path(data_source_id)].patch('') }
      end

      def public_project_url
        File.join(@connection.xapix_url, @org, @project)
      end

      private

      def rest_data_source_path
        "/projects/#{@org}/#{@project}/onboarding/data_sources/rest"
      end

      def data_source_preview_path(id)
        "/projects/#{@org}/#{@project}/onboarding/data_sources/#{id}/preview"
      end

      def resource_path(type, id)
        "/projects/#{@org}/#{@project}/#{translate_type(type)}/#{id}"
      end

      def resources_path(type)
        "/projects/#{@org}/#{@project}/#{translate_type(type)}"
      end

      def generic_resource_path
        "projects/#{@org}/#{@project}/resource"
      end

      def pipeline_preview_path(pipeline)
        "/projects/#{@org}/#{@project}/pipelines/#{pipeline}/preview"
      end

      def endpoint_preview_path(endpoint)
        "/projects/#{@org}/#{@project}/endpoints/#{endpoint}/preview"
      end

      def stream_processor_preview_path(stream_processor)
        "/projects/#{@org}/#{@project}/stream_processors/#{stream_processor}/preview"
      end

      def project_publications_path
        "/projects/#{@org}/#{@project}/publications"
      end

      def project_logss_path(correlation_id)
        "/projects/#{@org}/#{@project}/logs/#{correlation_id}"
      end
    end
  end
end
