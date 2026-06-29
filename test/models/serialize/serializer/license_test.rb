# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Serialize
    module Serializer
      class LicenseTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def serializer
          DataCycleCore::Serialize::Serializer::License
        end

        def tos_features
          { 'download' => { 'downloader' => { 'archive' => { 'zip' => { 'terms_of_use' => { 'de' => 'tos.txt' } } } } } }
        end

        # --- flags --------------------------------------------------------------
        test 'translatable? is true' do
          assert_predicate(serializer, :translatable?)
        end

        test 'mime_type is text/plain' do
          assert_equal('text/plain', serializer.mime_type)
        end

        # --- full serialize chain ----------------------------------------------
        test 'serialize_thing builds a copyright file and an introduction fallback' do
          item = struct_double(copyright_notice_override: nil, copyright_notice_computed: 'CC-BY-4.0', name: 'My Item', id: 'item-1')
          serialized_content = struct_double(id: 'item-1', file_name_with_extension: 'photo.jpg')

          # blank config forces terms_of_service_file to return nil -> the introduction fallback runs
          DataCycleCore.stub(:features, {}) do
            result = serializer.serialize_thing(content: item, language: 'de', serialized_collections: [[serialized_content]])

            assert_kind_of(DataCycleCore::Serialize::SerializedData::ContentCollection, result)
            files = result.collection

            assert_equal(2, files.size)
            assert_includes(files.first.data, 'photo.jpg: CC-BY-4.0')
          end
        end

        # --- terms of service file ---------------------------------------------
        test 'terms_of_service_file reads the configured terms file' do
          DataCycleCore.stub(:features, tos_features) do
            File.stub(:exist?, true) do
              File.stub(:binread, ->(*) { 'TERMS DATA' }) do
                result = serializer.send(:terms_of_service_file, 'de')

                assert_kind_of(DataCycleCore::Serialize::SerializedData::Content, result)
                assert_equal('TERMS DATA', result.data)
              end
            end
          end
        end

        test 'terms_of_service_file returns nil when the file cannot be read' do
          DataCycleCore.stub(:features, tos_features) do
            File.stub(:exist?, true) do
              File.stub(:binread, ->(*) { raise StandardError }) do
                assert_nil(serializer.send(:terms_of_service_file, 'de'))
              end
            end
          end
        end
      end
    end
  end
end
