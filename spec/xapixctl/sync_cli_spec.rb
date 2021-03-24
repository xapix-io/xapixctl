# frozen_string_literal: true

require 'spec_helper'
require 'xapixctl/cli'
require 'active_support/core_ext/object/deep_dup'

RSpec.describe Xapixctl::SyncCli do
  subject { Xapixctl::SyncCli }
  let(:default_args) { %w(--xapix_url=https://test.xapix --xapix_token=eyToken) }
  let(:resource_types) { [{ "type" => "Project", "context" => "Organization" }, { "type" => "AuthScheme", "context" => "Project" }, { "type" => "Credential", "context" => "Project" }] }
  let(:project_doc) { Psych.load(File.read('spec/fixtures/sync/project.yaml')) }
  let(:auth_scheme_doc) { Psych.load(File.read('spec/fixtures/sync/auth_scheme/cookie-test.yaml')) }

  before do
    stub_request(:get, "https://test.xapix/api/v1/resource_types").
      with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
      to_return(status: 200, body: { resource_types: resource_types }.to_json, headers: {})
  end

  context "help" do
    it do
      output = run_cli %w(help)
      expect(output).to include("Commands:")
    end
  end

  context "sync to-dir" do
    around do |example|
      Dir.mktmpdir("rspec-") do |dir|
        @temp_dir = Pathname.new(dir)
        example.run
      end
    end

    before do
      stub_request(:get, "https://test.xapix/api/v1/orgs/test/Project/project").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 200, body: project_doc.to_json, headers: {})

      stub_request(:get, "https://test.xapix/api/v1/projects/test/project/AuthScheme").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 200, body: { resource_ids: ['cookie-test'] }.to_json, headers: {})

      stub_request(:get, "https://test.xapix/api/v1/projects/test/project/Credential").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 200, body: { resource_ids: [] }.to_json, headers: {})

      stub_request(:get, "https://test.xapix/api/v1/projects/test/project/AuthScheme/cookie-test").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 200, body: auth_scheme_doc.to_json, headers: {})
    end

    it 'creates sync dir' do
      run_cli %W(to-dir #{@temp_dir} -p test/project)
      expect(@temp_dir.join('project.yaml')).to be_file
      expect(Psych.load(@temp_dir.join('project.yaml').read)).to eq(project_doc)
      expect(@temp_dir.join('auth_scheme', 'cookie-test.yaml')).to be_file
      expect(Psych.load(@temp_dir.join('auth_scheme', 'cookie-test.yaml').read)).to eq(auth_scheme_doc)
      expect(@temp_dir.join('credential')).not_to exist
      expect(@temp_dir.join('README.md')).to be_file
      expect(@temp_dir.join('README.md').read).to include("Project exported from https://test.xapix/test/project by xapixctl")
    end

    it 'excludes types' do
      run_cli %W(to-dir #{@temp_dir} -p test/project --exclude-types=AuthScheme Unknown)
      expect(@temp_dir.join('project.yaml')).to be_file
      expect(Psych.load(@temp_dir.join('project.yaml').read)).to eq(project_doc)
      expect(@temp_dir.join('auth_scheme')).not_to exist
      expect(@temp_dir.join('.excluded_types').read).to eq("AuthScheme\n")
    end

    it 'updates sync dir' do
      @temp_dir.join('auth_scheme').mkdir
      @temp_dir.join('auth_scheme', 'another-scheme.yaml').write("---")
      expect(@temp_dir.join('auth_scheme', 'another-scheme.yaml')).to exist
      run_cli %W(to-dir #{@temp_dir} -p test/project)
      expect(@temp_dir.join('project.yaml')).to be_file
      expect(@temp_dir.join('auth_scheme', 'cookie-test.yaml')).to be_file
      expect(@temp_dir.join('auth_scheme', 'another-scheme.yaml')).not_to exist
    end
  end

  context "sync from-dir" do
    let(:source_dir) { "./spec/fixtures/sync" }
    let(:adjusted_project) { project_doc.deep_dup.tap { |prj| prj['metadata']['id'] = 'project' } }

    before do
      stub_request(:put, "https://test.xapix/api/v1/orgs/test/resource").
        with(body: adjusted_project.to_json, headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken', 'Content-Type' => 'application/json' }).
        to_return(status: 200, body: { resource_ids: ["project"] }.to_json, headers: {})

      stub_request(:put, "https://test.xapix/api/v1/projects/test/project/resource").
        with(body: auth_scheme_doc.to_json, headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken', 'Content-Type' => 'application/json' }).
        to_return(status: 200, body: { resource_ids: ['cookie-test'] }.to_json, headers: {})

      stub_request(:get, "https://test.xapix/api/v1/projects/test/project/AuthScheme").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 200, body: { resource_ids: ['cookie-test', 'some-scheme'] }.to_json, headers: {})

      stub_request(:delete, "https://test.xapix/api/v1/projects/test/project/AuthScheme/some-scheme").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 204, body: "", headers: {})

      stub_request(:get, "https://test.xapix/api/v1/projects/test/project/Credential").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 200, body: { resource_ids: ['some-cred'] }.to_json, headers: {})

      stub_request(:delete, "https://test.xapix/api/v1/projects/test/project/Credential/some-cred").
        with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Bearer eyToken' }).
        to_return(status: 204, body: "", headers: {})
    end

    it 'updates remote' do
      output = run_cli %W(from-dir #{source_dir} -p test/project)
      expect(output).to eq(
        <<~EOOUT
          applying Project reqres-vehicles-new to project
          applying AuthScheme/Cookie cookie-test
          removing AuthScheme some-scheme
          removing Credential some-cred
        EOOUT
      )
    end

    it 'excludes types' do
      output = run_cli %W(from-dir #{source_dir} -p test/project --exclude-types=AuthScheme Credential)
      expect(output).to eq(
        <<~EOOUT
          Resource types excluded from sync: AuthScheme, Credential
          applying Project reqres-vehicles-new to project
        EOOUT
      )
    end

    context 'with existing excludes' do
      around do |example|
        Dir.mktmpdir("rspec-") do |dir|
          FileUtils.cp_r Pathname.new(source_dir).glob("*"), dir
          @temp_dir = Pathname.new(dir)
          @temp_dir.join(".excluded_types").write("AuthScheme\n")
          example.run
        end
      end

      it 'updates remote' do
        output = run_cli %W(from-dir #{@temp_dir} -p test/project)
        expect(output).to eq(
          <<~EOOUT
            Resource types excluded from sync: AuthScheme
            applying Project reqres-vehicles-new to project
            removing Credential some-cred
          EOOUT
        )
      end
    end
  end
end
