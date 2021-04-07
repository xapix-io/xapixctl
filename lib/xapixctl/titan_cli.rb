# frozen_string_literal: true

require 'xapixctl/base_cli'

module Xapixctl
  class TitanCli < BaseCli
    DEFAULT_METHODS = {
      "predict" => :predict,
      "performance" => :performance,
    }.freeze

    option :schema_import, desc: "Resource id of an existing Schema import"
    option :data, desc: "JSON encoded data for predict API", default: "[[1,2,3]]"
    desc "service URL", "build a service for the deployed model"
    long_desc <<-LONGDESC
      `xapixctl titan service URL` will build a ML service around a deployed ML model.

      We expect the following of the deployed ML model:

      - There should be a "POST /predict" endpoint. Use --data="JSON" to specify an example dataset the model expects.

      - If there is a "GET /performance" endpoint, it'll be made available. It's expected to return a JSON object with the properties 'accuracy', 'precision', 'recall', and 'min_acc_threshold'.

      Examples:
      \x5> $ xapixctl titan service https://services.demo.akoios.com/ai-model-name -p xapix/ml-project
    LONGDESC
    def service(akoios_url)
      url = URI.parse(akoios_url)
      schema = JSON.parse(RestClient.get(File.join(url.to_s, 'spec'), params: { host: url.hostname }, headers: { accept: :json }))
      patch_schema(schema)
      connector_refs = import_swagger(File.basename(url.path), schema)
      say "\n== Onboarding Connectors", :bold
      connectors = match_connectors_to_action(connector_refs)
      if connectors.empty?
        warn "\nNo valid connectors for ML service detected, not building service."
        exit 1
      end
      say "\n== Building Service", :bold
      service_doc = build_service(schema.dig('info', 'title'), connectors)
      res = prj_connection.apply(service_doc)
      say "\ncreated / updated service #{res.first}"
    end

    private

    def patch_schema(schema)
      predict_schema = schema.dig('paths', '/predict', 'post')
      if predict_schema
        predict_data = JSON.parse(options[:data]) rescue {}
        predict_schema['operationId'] = 'predict'
        predict_schema['parameters'].each do |param|
          if param['name'] == 'json' && param['in'] == 'body'
            param['schema']['properties'] = { "data" => extract_schema(predict_data) }
            param['schema']['example'] = { "data" => predict_data }
          end
        end
      end

      performane_schema = schema.dig('paths', '/performance', 'get')
      if performane_schema
        performane_schema['operationId'] = 'performance'
      end
    end

    def import_swagger(filename, schema)
      Tempfile.create([filename, '.json']) do |f|
        f.write(schema.to_json)
        f.rewind

        if options[:schema_import]
          result = prj_connection.update_schema_import(options[:schema_import], f)
          say "updated #{result.dig('resource', 'kind')} #{result.dig('resource', 'id')}"
        else
          result = prj_connection.add_schema_import(f)
          say "created #{result.dig('resource', 'kind')} #{result.dig('resource', 'id')}"
        end
        result.dig('schema_import', 'updated_resources')
      end
    end

    def match_connectors_to_action(connector_refs)
      connector_refs.map do |connector_ref|
        connector = prj_connection.resource(connector_ref['kind'], connector_ref['id'])
        action = DEFAULT_METHODS[connector.dig('definition', 'name')]
        say "\n#{connector['kind']} #{connector.dig('definition', 'name')} -> "
        if action
          say "#{action} action"
          updated_connector = update_connector_with_preview(connector)
          [action, updated_connector] if updated_connector
        else
          say "no action type detected, ignoring"
          nil
        end
      end.compact
    end

    def update_connector_with_preview(connector)
      say "fetching preview for #{connector['kind']} #{connector.dig('definition', 'name')}..."
      preview_details = prj_connection.data_source_preview(connector.dig('metadata', 'id'))
      preview = preview_details.dig('preview', 'sample')
      say "got a #{preview['status']} response: #{preview['body']}"
      if preview['status'] != 200
        say "unexpected status, please check data or model"
      elsif yes?("Does this look alright?", :bold)
        res = prj_connection.accept_data_source_preview(connector.dig('metadata', 'id'))
        return res.dig('data_source', 'resource_description')
      end
      nil
    end

    def extract_schema(data_sample)
      case data_sample
      when Array
        { type: 'array', items: extract_schema(data_sample[0]) }
      when Hash
        { type: 'object', properties: data_sample.transform_values { |v| extract_schema(v) } }
      when Numeric
        { type: 'number' }
      else
        {}
      end
    end

    def build_service(title, connectors)
      {
        version: 'v1',
        kind: 'Service',
        metadata: { id: title.parameterize },
        definition: {
          name: title.humanize,
          actions: connectors.map { |action, connector| build_service_action(action, connector) }
        }
      }
    end

    def build_service_action(action_type, connector)
      {
        name: action_type,
        parameter_schema: parameter_schema(action_type, connector),
        result_schema: result_schema(action_type),
        pipeline: { units: pipeline_units(action_type, connector) }
      }
    end

    def parameter_schema(action_type, connector)
      case action_type
      when :predict
        { type: 'object', properties: {
          data: connector.dig('definition', 'parameter_schema', 'properties', 'body', 'properties', 'data'),
        } }
      when :performance
        { type: 'object', properties: {} }
      end
    end

    def result_schema(action_type)
      case action_type
      when :predict
        { type: 'object', properties: {
          prediction: { type: 'object', properties: { percent: { type: 'number' }, raw: { type: 'number' } } },
          success: { type: 'boolean' },
          error: { type: 'string' }
        } }
      when :performance
        { type: 'object', properties: {
          performance: {
            type: 'object', properties: {
              accuracy: { type: 'number' },
              precision: { type: 'number' },
              recall: { type: 'number' },
              min_acc_threshold: { type: 'number' }
            }
          }
        } }
      end
    end

    def pipeline_units(action_type, connector)
      case action_type
      when :predict
        [entry_unit, predict_unit(connector), predict_result_unit]
      when :performance
        [entry_unit, performance_unit(connector), performance_result_unit]
      end
    end

    def entry_unit
      { version: 'v2', kind: 'Unit/Entry',
        metadata: { id: 'entry' },
        definition: { name: 'Entry' } }
    end

    def predict_unit(connector)
      leafs = extract_leafs(connector.dig('definition', 'parameter_schema', 'properties', 'body'))
      { version: 'v2', kind: 'Unit/DataSource',
        metadata: { id: 'predict' },
        definition: {
          name: 'Predict',
          inputs: ['entry'],
          data_source: connector.dig('metadata', 'id'),
          formulas: leafs.map { |leaf|
            { ref: leaf[:node]['$id'], formula: (['', 'entry'] + leaf[:path]).join('.') }
          }
        } }
    end

    def predict_result_unit
      { version: 'v2', kind: 'Unit/Result',
        metadata: { id: 'result' },
        definition: {
          name: 'Result',
          inputs: ['predict'],
          formulas: [{
            ref: "#prediction.percent",
            formula: "IF(.predict.status = 200, ROUND(100*coerce.to-float(.predict.body), 2))"
          }, {
            ref: "#prediction.raw",
            formula: "IF(.predict.status = 200, coerce.to-float(.predict.body))"
          }, {
            ref: "#success",
            formula: ".predict.status = 200"
          }, {
            ref: "#error",
            formula: "IF(.predict.status <> 200, 'Model not trained!')"
          }],
          parameter_sample: {
            "prediction" => { "percent" => 51.12, "raw" => 0.5112131 },
            "success" => true,
            "error" => nil
          }
        } }
    end

    def performance_unit(connector)
      { version: 'v2', kind: 'Unit/DataSource',
        metadata: { id: 'performance' },
        definition: {
          name: 'Performance',
          inputs: ['entry'],
          data_source: connector.dig('metadata', 'id')
        } }
    end

    def performance_result_unit
      { version: 'v2', kind: 'Unit/Result',
        metadata: { id: 'result' },
        definition: {
          name: 'Result',
          inputs: ['performance'],
          formulas: [{
            ref: "#performance.recall",
            formula: "WITH(data, JSON.DECODE(REGEXREPLACE(performance.body, \"'\", \"\\\"\")), .data.recall)"
          }, {
            ref: "#performance.accuracy",
            formula: "WITH(data, JSON.DECODE(REGEXREPLACE(performance.body, \"'\", \"\\\"\")), .data.accuracy)"
          }, {
            ref: "#performance.precision",
            formula: "WITH(data, JSON.DECODE(REGEXREPLACE(performance.body, \"'\", \"\\\"\")), .data.precision)"
          }, {
            ref: "#performance.min_acc_threshold",
            formula: "WITH(data, JSON.DECODE(REGEXREPLACE(performance.body, \"'\", \"\\\"\")), .data.min_acc_threshold)"
          }],
          parameter_sample: {
            "performance" => {
              "recall" => 0.8184713375796179,
              "accuracy" => 0.9807847896440129,
              "precision" => 0.8711864406779661,
              "min_acc_threshold" => 0.84,
            }
          }
        } }
    end

    def extract_leafs(schema, current_path = [])
      return unless schema
      case schema['type']
      when 'object'
        schema['properties'].flat_map { |key, sub_schema| extract_leafs(sub_schema, current_path + [key]) }.compact
      when 'array'
        extract_leafs(schema['items'], current_path + [:[]])
      else
        { path: current_path, node: schema }
      end
    end
  end
end
