# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the credentials concept loader. The Mongo aggregation is
      # stubbed via Generic::Collection2.with so no MongoDB is touched.
      class DownloadConceptsCredentialsFromDataCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::DownloadConceptsCredentialsFromData
        end

        # mongo double: mongo.collection.aggregate(pipeline).to_a => []
        # the pipeline it was called with is recorded into +recorder+
        def mongo_double(recorder = [])
          collection = Class.new {
            define_method(:aggregate) do |pipeline|
              recorder.replace(pipeline)
              []
            end
          }.new
          Class.new {
            define_method(:collection) { collection }
          }.new
        end

        # runs load_concepts_from_mongo against the double and returns its $project stage
        def projection_stage_for(download_options)
          pipeline = []
          DataCycleCore::Generic::Collection2.stub(:with, ->(_read_type, &block) { block.call(mongo_double(pipeline)) }) do
            subject.load_concepts_from_mongo(options: { download: { read_type: 'credentials' }.merge(download_options) }, source_filter: {})
          end

          pipeline.find { |stage| stage.key?('$project') }['$project']
        end

        # [#50666] the projected priority is stripped from the payload again, so the claim has to reach
        # props_from_config through the options -- otherwise an unprioritised concept step would stop
        # claiming what it writes and every concept dump would be rewritten once to drop the key.
        test 'download_content claims what it writes at the default priority' do
          captured = nil
          DataCycleCore::Generic::Common::DownloadFunctions.stub(:download_content, ->(**kwargs) { captured = kwargs[:options] }) do
            subject.download_content(utility_object: nil, options: { download: { read_type: 'credentials' } })
          end

          assert_equal DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::DEFAULT_STEP_PRIORITY,
                       captured.dig(:download, :priority)
        end

        test 'download_content leaves a configured priority alone' do
          captured = nil
          DataCycleCore::Generic::Common::DownloadFunctions.stub(:download_content, ->(**kwargs) { captured = kwargs[:options] }) do
            subject.download_content(utility_object: nil, options: { download: { read_type: 'credentials', priority: 0 } })
          end

          assert_equal 0, captured.dig(:download, :priority)
        end

        test 'load_concepts_from_mongo raises without a read_type' do
          assert_raises(ArgumentError) do
            subject.load_concepts_from_mongo(options: { download: {} }, source_filter: {})
          end
        end

        test 'load_concepts_from_mongo builds and runs the aggregation' do
          mongo = mongo_double
          DataCycleCore::Generic::Collection2.stub(:with, ->(_read_type, &block) { block.call(mongo) }) do
            result = subject.load_concepts_from_mongo(
              options: { download: { read_type: 'credentials', priority: 3 } },
              source_filter: { 'foo' => 'bar' }
            )

            assert_equal([], result)
          end
        end

        # [#50666] the stage projects no priority under either name. It cannot leak a source-owned one
        # either: a $project that rebuilds `data` field by field emits only the fields it lists, which
        # is what made the pre-#50666 bare number - an inclusion flag - pass the source's value through.
        test 'the aggregation projects no priority under either name' do
          exp = {
            'data.id' => '$external_system.credential_keys',
            'data.name' => '$external_system.credential_keys'
          }

          assert_equal(exp, projection_stage_for({ priority: 3 }))
          assert_equal(exp, projection_stage_for({}))
        end

        test 'data_id and data_name read hashed/plain values' do
          assert_equal(Digest::MD5.hexdigest('x'), subject.data_id('MD5', { 'id' => 'x' }))
          assert_equal('x', subject.data_id(nil, { 'id' => 'x' }))
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
