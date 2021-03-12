# frozen_string_literal: true

require 'spec_helper'
require 'xapixctl/cli'

RSpec.describe Xapixctl::Cli do
  subject { Xapixctl::Cli }
  let(:default_args) { %w(--xapix_url=https://test.xapix --xapix_token=eyToken) }

  context "help" do
    it do
      output = run_cli %w(help)
      expect(output).to include("Commands:")
    end
  end

  context "get Project" do
    let(:result_doc) do
      { 'version' => 'v1', 'kind' => "Project",
        'metadata' => { 'id' => 'test' },
        'definition' => { 'name' => 'Test Project' } }
    end

    before do
      stub_request(:get, "https://test.xapix/api/v1/orgs/my_org/Project/test").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 200, body: result_doc.to_json, headers: {})
    end

    it do
      output = run_cli %w(get Project test -o my_org)
      expect(output).to include("id  : test")
      expect(output).to include("name: Test Project")
    end
  end

  context "get ApiPublishing in Project" do
    let(:result_doc) do
      { 'version' => 'v1', 'kind' => "ApiPublishing",
        'metadata' => { 'id' => 'test', 'project' => 'test' },
        'definition' => { 'user_management' => 'shisa' } }
    end

    before do
      stub_request(:get, "https://test.xapix/api/v1/projects/my_org/test/ApiPublishing/test").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 200, body: result_doc.to_json, headers: {})
    end

    it do
      output = run_cli %w(get ApiPublishing test -p my_org/test)
      expect(output).to include("id  : test")
      expect(output).to include("kind: ApiPublishing")
    end
  end

  context "apply export.yaml" do
    before do
      docs = Psych.load_stream(File.read('spec/fixtures/export.yaml'))
      docs.each do |doc|
        stub_request(:put, "https://test.xapix/api/v1/projects/my_org/test/resource").
          with(body: doc.to_json, headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken', 'Content-Type' => 'application/json' }).
          to_return(status: 200, body: "", headers: {})
      end
    end

    it do
      output = run_cli %w(apply -f ./spec/fixtures/export.yaml -p my_org/test)
      expect(output).to include("applying Project reqres-vehicles-new")
      expect(output).to include("applying AuthScheme/Cookie cookie-test")
    end
  end

  context "delete export.yaml" do
    before do
      docs = Psych.load_stream(File.read('spec/fixtures/export.yaml'))
      docs.each do |doc|
        stub_request(:delete, "https://test.xapix/api/v1/projects/my_org/test/#{doc['kind'].split('/').first}/#{doc['metadata']['id']}").
          with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
          to_return(status: 204, body: "", headers: {})
      end
    end

    it do
      output = run_cli %w(delete -f ./spec/fixtures/export.yaml -p my_org/test)
      expect(output).to include("DELETED Project reqres-vehicles-new")
      expect(output).to include("DELETED AuthScheme/Cookie cookie-test")
    end
  end
end
