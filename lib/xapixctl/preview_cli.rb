# frozen_string_literal: true

require 'xapixctl/base_cli'

module Xapixctl
  class PreviewCli < BaseCli
    option :format, aliases: "-f", default: 'text', enum: ['text', 'yaml', 'json'], desc: "Output format"
    desc "pipeline ID", "Preview a pipeline"
    long_desc <<-LONGDESC
      `xapixctl preview pipeline` will return a preview of the given pipeline.

      The preview function will not call any external data sources but calculate a preview based on the provided sample data.

      To preview a pipeline attached to an endpoint, please use `xapixctl preview endpoint` to see the correct preview.

      Examples:
      \x5> $ xapixctl preview pipeline -o xapix -p some-project pipeline
      \x5> $ xapixctl preview pipeline -p xapix/some-project pipeline
    LONGDESC
    def pipeline(pipeline)
      say prj_connection.pipeline_preview(pipeline, format: options[:format].to_sym)
    end

    option :format, aliases: "-f", default: 'text', enum: ['text', 'yaml', 'json'], desc: "Output format"
    desc "endpoint ID", "Preview an endpoint"
    long_desc <<-LONGDESC
      `xapixctl preview endpoint` will return a preview of the given endpoint.

      The preview function will not call any external data sources but calculate a preview based on the provided sample data.

      Examples:
      \x5> $ xapixctl preview endpoint -o xapix -p some-project endpoint
      \x5> $ xapixctl preview endpoint -p xapix/some-project endpoint
    LONGDESC
    def endpoint(endpoint)
      say prj_connection.endpoint_preview(endpoint, format: options[:format].to_sym)
    end

    option :format, aliases: "-f", default: 'text', enum: ['text', 'yaml', 'json'], desc: "Output format"
    desc "stream-processor ID", "Preview a stream processor"
    long_desc <<-LONGDESC
      `xapixctl preview stream-processor` will return a preview of the given stream processor.

      The preview function will not call any external data sources but calculate a preview based on the provided sample data.

      Examples:
      \x5> $ xapixctl preview stream-processor -o xapix -p some-project processor
      \x5> $ xapixctl preview stream-processor -p xapix/some-project processor
    LONGDESC
    def stream_processor(stream_processor)
      say prj_connection.stream_processor_preview(stream_processor, format: options[:format].to_sym)
    end
  end
end
