# frozen_string_literal: true

require 'test_helper'
require 'csv'
require 'tmpdir'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the CSV download iterator helpers (no Mongo / no download
      # pipeline needed — the parser and id helpers are exercised directly).
      class DownloadDataFromCsvCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::DownloadDataFromCsv
        end

        test 'load_data_from_csv reads rows and merges id and modifiedAt' do
          Dir.mktmpdir do |dir|
            path = File.join(dir, 'data.csv')
            File.write(path, "id;name\n1;Foo\n2;Bar\n")

            data = subject.load_data_from_csv(options: { download: { file: path, data_id_path: 'id', separator: ';' } })

            assert_equal(2, data.size)
            assert_equal('1', data.first['id'])
            assert_equal('Foo', data.first['name'])
            assert(data.first.key?('modifiedAt'))
          end
        end

        test 'load_data_from_csv raises without a file path' do
          assert_raises(ArgumentError) { subject.load_data_from_csv(options: { download: {} }) }
        end

        test 'load_data_from_csv raises without a data_id_path' do
          Dir.mktmpdir do |dir|
            path = File.join(dir, 'data.csv')
            File.write(path, "id\n1\n")

            assert_raises(ArgumentError) { subject.load_data_from_csv(options: { download: { file: path } }) }
          end
        end

        test 'data_id hashes the id with MD5 or returns it as a string' do
          assert_equal(Digest::MD5.hexdigest('x'), subject.data_id('MD5', { 'id' => 'x' }))
          assert_equal('42', subject.data_id(nil, { 'id' => 42 }))
        end
      end
    end
  end
end
