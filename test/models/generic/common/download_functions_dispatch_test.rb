# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class GenericCommonDownloadFunctionsDispatchTest < ActiveSupport::TestCase
    SUBJECT = DataCycleCore::Generic::Common::DownloadFunctions

    test 'bson_to_hash converts nested bson documents to plain hashes' do
      document = BSON::Document.new(
        'a' => BSON::Document.new('b' => 1),
        'c' => [BSON::Document.new('d' => 2), 'plain']
      )

      result = SUBJECT.bson_to_hash(document)

      assert_instance_of ::Hash, result
      assert_instance_of ::Hash, result['a']
      assert_instance_of ::Hash, result['c'].first
      assert_equal 1, result.dig('a', 'b')
      assert_equal 'plain', result['c'].last
    end

    test 'bson_to_hash returns non-hash values unchanged' do
      assert_equal 'string', SUBJECT.bson_to_hash('string')
      assert_nil SUBJECT.bson_to_hash(nil)
    end

    test 'diff? detects changed and unchanged data' do
      assert SUBJECT.diff?({ 'a' => 1 }, { 'a' => 2 })
      assert SUBJECT.diff?(nil, { 'a' => 1 })
      assert_not SUBJECT.diff?({ 'a' => 1 }, { 'a' => 1 })
    end

    test 'download_data dispatches to download_content by default' do
      called = []
      collector = lambda { |**kwargs|
        called << kwargs
        true
      }

      SUBJECT.stub(:download_content, collector) do
        SUBJECT.download_data(download_object: :dummy_object, data_id: nil, data_name: nil, options: {})
      end

      assert_equal 1, called.size
      assert_equal :dummy_object, called.first[:download_object]
      assert_kind_of Proc, called.first[:credential]
    end

    test 'download_data maps legacy strategies to download_content variants' do
      called = []
      collector = lambda { |**kwargs|
        called << kwargs
        true
      }

      SUBJECT.stub(:download_content, collector) do
        SUBJECT.download_data(download_object: nil, data_id: nil, data_name: nil, options: { iteration_strategy: 'download_parallel' })
      end
      SUBJECT.stub(:download_content_all, collector) do
        SUBJECT.download_data(download_object: nil, data_id: nil, data_name: nil, options: { download: { iteration_strategy: 'download_optimized_all' } })
      end

      assert_equal 2, called.size
    end

    test 'download_data dispatches to download_all and raises for unknown strategies' do
      called = []
      collector = lambda { |**kwargs|
        called << kwargs
        true
      }

      SUBJECT.stub(:download_all, collector) do
        SUBJECT.download_data(download_object: nil, data_id: nil, data_name: nil, options: { iteration_strategy: 'download_all' })
      end

      assert_equal 1, called.size
      assert_raises(RuntimeError) do
        SUBJECT.download_data(download_object: nil, data_id: nil, data_name: nil, options: { iteration_strategy: 'bogus_strategy' })
      end
    end
  end
end
