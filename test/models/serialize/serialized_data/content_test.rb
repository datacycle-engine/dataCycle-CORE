# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Serialize
    module SerializedData
      class ContentTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def build(**)
          defaults = { data: nil, mime_type: 'image/jpeg', file_name: 'file', id: 'id-1' }
          DataCycleCore::Serialize::SerializedData::Content.new(**defaults, **)
        end

        def remote
          build(data: nil, mime_type: nil, is_remote: true, data_url: 'http://example.com/file.jpg')
        end

        def response_double
          Struct.new(:headers).new({ 'content-type' => 'image/jpeg' })
        end

        test 'parsed_data_uri parses the data url and is nil when blank' do
          assert_equal('example.com', build(data_url: 'http://example.com/file.jpg').parsed_data_uri.hostname)
          assert_nil(build.parsed_data_uri)
        end

        test 'faraday_connection builds a configured connection' do
          assert_kind_of(Faraday::Connection, build.faraday_connection)
        end

        test 'mime_type fetches the content type of a remote file via HEAD' do
          content = remote
          faraday = Object.new
          faraday.define_singleton_method(:head) { |_uri| Struct.new(:headers).new({ 'content-type' => 'image/png' }) }

          content.stub(:faraday_connection, faraday) do
            assert_equal('image/png', content.mime_type)
          end
        end

        test 'active_storage_file_path resolves the disk service path' do
          service = Object.new
          service.define_singleton_method(:path_for) { |key| "/store/#{key}" }
          file = Struct.new(:service).new(service)
          record = Struct.new(:file).new(file)
          data = Object.new
          data.define_singleton_method(:key) { 'abc' }
          data.define_singleton_method(:record) { record }

          assert_equal('/store/abc', build(data:).active_storage_file_path)
        end

        test 'stream_data yields the result of a proc' do
          result = nil
          build(data: -> { 'PROC' }).stream_data { |chunk| result = chunk }

          assert_equal('PROC', result)
        end

        test 'stream_data iterates an enumerator' do
          chunks = []
          build(data: [1, 2].to_enum).stream_data { |chunk| chunks << chunk }

          assert_equal([1, 2], chunks)
        end

        test 'stream_data reads a local file' do
          data = Object.new
          data.define_singleton_method(:read) { 'LOCAL' }
          content = build(data:)
          result = nil

          content.stub(:local_file?, true) do
            content.stream_data { |chunk| result = chunk }
          end

          assert_equal('LOCAL', result)
        end

        test 'stream_data downloads a remote file in chunks' do
          content = remote
          response = response_double
          faraday = Object.new
          faraday.define_singleton_method(:get) do |_uri, &block|
            options = Struct.new(:on_data).new
            block.call(Struct.new(:options).new(options))
            options.on_data.call('CHUNK', 5, nil)
            response
          end

          chunks = []
          content.stub(:faraday_connection, faraday) do
            content.stream_data { |chunk| chunks << chunk }
          end

          assert_equal(['CHUNK'], chunks)
          assert(content.remote_file_loaded)
        end

        test 'each_data wraps stream_data in an enumerator' do
          assert_equal(['PLAIN'], build(data: 'PLAIN').each_data.to_a)
        end
      end
    end
  end
end
