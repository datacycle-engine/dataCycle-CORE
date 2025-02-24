# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DownloadFromDataTest < ActiveSupport::TestCase
    include DataCycleCore::Generic::Common::Extensions::DownloadFromData

    def setup
      @data = { 'id' => '12345', 'name' => 'Test Data', 'description' => 'This is a test data' }
    end

    def self.transform_method(data)
      "transformed_#{data['id']}"
    end

    def self.cleanup_method(data)
      data.delete('description')
      data
    end

    test 'data_id returns id as string when transformation is blank' do
      result = data_id(nil, @data)
      assert_equal '12345', result
    end

    test 'data_id returns transformed id' do
      transformation = { module: 'DataCycleCore::DownloadFromDataTest', method: 'transform_method' }
      result = data_id(transformation, @data)
      assert_equal(DownloadFromDataTest.transform_method(@data), result)
    end

    test 'cleanup_data returns cleaned data' do
      cleanup_config = { module: 'DataCycleCore::DownloadFromDataTest', method: 'cleanup_method' }
      result = cleanup_data(cleanup_config, @data)
      assert_equal(DownloadFromDataTest.cleanup_method(@data), result)
    end

    test 'id_md5_transformation returns MD5 hash of id' do
      result = id_md5_transformation(@data)
      assert_equal Digest::MD5.hexdigest('12345'), result
    end

    test 'id_sha1_transformation returns SHA1 hash of id' do
      result = id_sha1_transformation(@data)
      assert_equal Digest::SHA1.hexdigest('12345'), result
    end
  end
end
