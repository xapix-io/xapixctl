# frozen_string_literal: true

require 'spec_helper'
require 'xapixctl/cli'

RSpec.describe Xapixctl::ConnectorCli do
  subject { Xapixctl::ConnectorCli }
  let(:default_args) { %w(--xapix_url=https://test.xapix --xapix_token=eyToken) }

  context "help" do
    it do
      output = run_cli %w(help)
      expect(output).to include("Commands:")
    end
  end

  context "import" do
    let(:schema_filename) { './spec/fixtures/schemas/openapi.yaml' }
    let(:import_report) { { issues: [], validation_issues: [] } }
    let(:updated_resources) do
      [
        { "id" => "get_pets", "project" => "demo-project", "kind" => "DataSource/REST" },
        { "id" => "post_pet", "project" => "demo-project", "kind" => "DataSource/REST" }
      ]
    end
    let(:schema_import_response) do
      {
        resource: { id: "openapi-2-0-http-petstore-swagger-io-api", kind: "Schema", project: "project" },
        schema_import: {
          id: "openapi-2-0-http-petstore-swagger-io-api",
          report: import_report,
          updated_resources: updated_resources
        }
      }
    end

    context 'new' do
      before do
        stub_request(:post, "https://test.xapix/api/v1/projects/test/project/onboarding/schema_imports").
          to_return(status: 201, body: schema_import_response.to_json, headers: {}).
          with do |req|
            expect(req.body).to match(/Content-Disposition: form-data;.+ filename="openapi.yaml"/)
            expect(req.headers['Content-Type']).to include('multipart/form-data; boundary=----RubyFormBoundary')
          end
      end

      it 'reports results' do
        output = run_cli %W(import #{schema_filename} -p test/project)
        expect(output).to eq(
          <<~EOOUT
            uploading as new import: ./spec/fixtures/schemas/openapi.yaml...
            created Schema openapi-2-0-http-petstore-swagger-io-api

            connectors:
             - DataSource/REST get_pets
             - DataSource/REST post_pet
          EOOUT
        )
      end

      context 'with issues' do
        let(:import_report) do
          {
            issues: ["Connector type \"application/x-custom and application/x-super-custom\" not supported"],
            validation_issues: ["Something didn't validate"]
          }
        end

        it 'reports results' do
          output = run_cli %W(import #{schema_filename} -p test/project)
          expect(output).to eq(
            <<~EOOUT
              uploading as new import: ./spec/fixtures/schemas/openapi.yaml...
              created Schema openapi-2-0-http-petstore-swagger-io-api

              import issues:
               - Connector type "application/x-custom and application/x-super-custom" not supported

              validation issues:
               - Something didn't validate

              connectors:
               - DataSource/REST get_pets
               - DataSource/REST post_pet
            EOOUT
          )
        end
      end

      context 'no connectors' do
        let(:updated_resources) { [] }

        it 'reports results' do
          output = run_cli %W(import #{schema_filename} -p test/project)
          expect(output).to eq(
            <<~EOOUT
              uploading as new import: ./spec/fixtures/schemas/openapi.yaml...
              created Schema openapi-2-0-http-petstore-swagger-io-api

              no connectors created/updated.
            EOOUT
          )
        end
      end
    end

    context 'existing' do
      before do
        stub_request(:patch, "https://test.xapix/api/v1/projects/test/project/onboarding/schema_imports/openapi-2-0-http-petstore-swagger-io-api").
          to_return(status: 200, body: schema_import_response.to_json, headers: {}).
          with do |req|
            expect(req.body).to match(/Content-Disposition: form-data;.+ filename="openapi.yaml"/)
            expect(req.headers['Content-Type']).to include('multipart/form-data; boundary=----RubyFormBoundary')
          end
      end

      it 'reports results' do
        output = run_cli %W(import #{schema_filename} -p test/project --schema-import openapi-2-0-http-petstore-swagger-io-api)
        expect(output).to eq(
          <<~EOOUT
            uploading to update schema import 'openapi-2-0-http-petstore-swagger-io-api': ./spec/fixtures/schemas/openapi.yaml...
            updated Schema openapi-2-0-http-petstore-swagger-io-api

            connectors:
             - DataSource/REST get_pets
             - DataSource/REST post_pet
          EOOUT
        )
      end
    end
  end
end
