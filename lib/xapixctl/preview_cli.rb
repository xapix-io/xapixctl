# frozen_string_literal: true

require 'xapixctl/base_cli'

module Xapixctl
  class Preview < BaseCli
    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project", required: true
    option :format, aliases: "-f", default: 'text', enum: ['text', 'yaml', 'json'], desc: "Output format"
    desc "pipeline ID", "Preview a pipeline"
    long_desc <<-LONGDESC
      `xapixctl preview pipeline` will return a preview of the given pipeline.

      The preview function will not call any external data sources but calculate a preview based on the provided sample data.

      To preview a pipeline attached to an endpoint, please use `xapixctl preview endpoint` to see the correct preview.

      Examples:
      \x5> $ xapixctl preview pipeline -o xapix -p some-project pipeline
    LONGDESC
    def pipeline(pipeline)
      connection.pipeline_preview(pipeline, org: options[:org], project: options[:project], format: options[:format].to_sym) do |res|
        res.on_success { |preview| puts preview }
        res.on_error { |err, result| warn_api_error('could not fetch preview', err, result) }
      end
    end

    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project", required: true
    option :format, aliases: "-f", default: 'text', enum: ['text', 'yaml', 'json'], desc: "Output format"
    desc "endpoint ID", "Preview an endpoint"
    long_desc <<-LONGDESC
      `xapixctl preview endpoint` will return a preview of the given endpoint.

      The preview function will not call any external data sources but calculate a preview based on the provided sample data.

      Examples:
      \x5> $ xapixctl preview endpoint -o xapix -p some-project endpoint
    LONGDESC
    def endpoint(endpoint)
      connection.endpoint_preview(endpoint, org: options[:org], project: options[:project], format: options[:format].to_sym) do |res|
        res.on_success { |preview| puts preview }
        res.on_error { |err, result| warn_api_error('could not fetch preview', err, result) }
      end
    end

    option :org, aliases: "-o", desc: "Organization", required: true
    option :project, aliases: "-p", desc: "Project", required: true
    option :format, aliases: "-f", default: 'text', enum: ['text', 'yaml', 'json'], desc: "Output format"
    desc "stream-processor ID", "Preview a stream processor"
    long_desc <<-LONGDESC
      `xapixctl preview stream-processor` will return a preview of the given stream processor.

      The preview function will not call any external data sources but calculate a preview based on the provided sample data.

      Examples:
      \x5> $ xapixctl preview stream-processor -o xapix -p some-project processor
    LONGDESC
    def stream_processor(stream_processor)
      connection.stream_processor_preview(stream_processor, org: options[:org], project: options[:project], format: options[:format].to_sym) do |res|
        res.on_success { |preview| puts preview }
        res.on_error { |err, result| warn_api_error('could not fetch preview', err, result) }
      end
    end
  end
end
