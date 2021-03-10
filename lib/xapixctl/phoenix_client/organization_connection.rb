# frozen_string_literal: true

module Xapixctl
  module PhoenixClient
    class OrganizationConnection
      attr_reader :org

      def initialize(connection, org)
        @connection = connection
        @client = connection.client
        @org = org
      end

      def resource(resource_type, resource_id, format: :hash, &block)
        result_handler(block).
          formatter(FORMATTERS[format]).
          run { @client[resource_path(resource_type, resource_id)].get }
      end

      def resource_ids(resource_type, &block)
        result_handler(block).
          prepare_data(->(data) { data['resource_ids'] }).
          run { @client[resources_path(resource_type)].get }
      end

      def apply(resource_description, &block)
        result_handler(block).
          prepare_data(->(data) { data['resource_ids'] }).
          run { @client[generic_resource_path].put(resource_description.to_json, content_type: :json) }
      end

      def delete(resource_type, resource_id, &block)
        result_handler(block).
          run { @client[resource_path(resource_type, resource_id)].delete }
      end

      private

      def result_handler(block)
        @connection.result_handler(block)
      end

      def resource_path(type, id)
        "/orgs/#{@org}/#{translate_type(type)}/#{id}"
      end

      def resources_path(type)
        "/orgs/#{@org}/#{translate_type(type)}"
      end

      def generic_resource_path
        "orgs/#{@org}/resource"
      end

      def translate_type(resource_type)
        return 'ApiPublishingRole' if resource_type == 'ApiPublishing/Role'
        resource_type.sub(%r[/.*], '') # cut off everything after first slash
      end
    end
  end
end
