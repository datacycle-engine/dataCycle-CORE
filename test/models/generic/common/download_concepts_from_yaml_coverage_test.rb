# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the YAML concept loader (pure file parsing; the download
      # entry point is exercised with DownloadFunctions stubbed, no Mongo).
      class DownloadConceptsFromYamlCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::DownloadConceptsFromYaml
        end

        test 'load_concepts_from_yaml maps id, name and modifiedAt' do
          Dir.mktmpdir do |dir|
            path = File.join(dir, 'concepts.yml')
            File.write(path, "key1: Name 1\nkey2:\n  de: Name 2\n")

            data = subject.load_concepts_from_yaml(options: { download: { file: path } }, locale: :de)

            assert_equal(2, data.size)
            assert_equal('key1', data.first['id'])
            assert(data.first.key?('modifiedAt'))
          end
        end

        test 'load_concepts_from_yaml raises without a file path' do
          assert_raises(ArgumentError) { subject.load_concepts_from_yaml(options: { download: {} }, locale: :de) }
        end

        test 'data_id and data_name read the hashed/plain values' do
          assert_equal(Digest::MD5.hexdigest('x'), subject.data_id('MD5', { 'id' => 'x' }))
          assert_equal('42', subject.data_id(nil, { 'id' => 42 }))
          assert_equal('Foo', subject.data_name({ 'name' => 'Foo' }))
        end

        test 'download_content delegates to DownloadFunctions' do
          DataCycleCore::Generic::Common::DownloadFunctions.stub(:download_content, nil) do
            assert_nothing_raised do
              subject.download_content(utility_object: struct_double(id: 'x'), options: { download: {} })
            end
          end
        end
      end
    end
  end
end
