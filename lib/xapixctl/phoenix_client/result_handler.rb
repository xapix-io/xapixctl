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
  end
end
