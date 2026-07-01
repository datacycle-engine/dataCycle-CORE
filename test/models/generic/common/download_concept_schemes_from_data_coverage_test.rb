# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the concept-scheme loader. The Mongo aggregation is stubbed
      # via Generic::Collection2.with so no MongoDB is touched.
      class DownloadConceptSchemesFromDataCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::DownloadConceptSchemesFromData
        end

        def mongo_double
          collection = Class.new { def aggregate(*) = [] }.new
          Class.new {
            define_method(:collection) { collection }
          }.new
        end

        test 'load_concept_schemes_from_mongo raises without a read_type' do
          assert_raises(ArgumentError) do
            subject.load_concept_schemes_from_mongo(options: { download: {} }, locale: :de, source_filter: {})
          end
        end

        test 'load_concept_schemes_from_mongo builds and runs the aggregation' do
          mongo = mongo_double
          DataCycleCore::Generic::Collection2.stub(:with, ->(_read_type, &block) { block.call(mongo) }) do
            result = subject.load_concept_schemes_from_mongo(
              options: { download: { read_type: 'schemes' } },
              locale: :de,
              source_filter: { 'foo' => 'bar' }
            )

            assert_equal([], result)
          end
        end

        test 'data_id and data_name read the plain values' do
          assert_equal('an-id', subject.data_id({ 'id' => 'an-id' }))
          assert_equal('a-name', subject.data_name({ 'name' => 'a-name' }))
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
