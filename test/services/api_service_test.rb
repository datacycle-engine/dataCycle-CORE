# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ApiServiceTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def service
      @service ||= Class.new { include DataCycleCore::ApiService }.new
    end

    test 'api_to_property_name strips api prefixes and normalizes' do
      assert_equal 'foo_bar', service.api_to_property_name('dc:fooBar')
      assert_equal 'baz', service.api_to_property_name('dcls:baz')
    end

    test 'api_advanced_attribute_mapping returns an array for unknown attributes' do
      assert_kind_of Array, service.api_advanced_attribute_mapping('dc:unknownAttribute')
    end

    test 'api_attribute_mapping returns an array for unknown attributes' do
      assert_kind_of Array, service.api_attribute_mapping('dc:unknownAttribute', 'string')
    end

    test 'api_advanced_attribute_type returns an array for unknown attributes' do
      assert_kind_of Array, service.api_advanced_attribute_type('dc:unknownAttribute')
    end

    test 'property_name_mapping returns nil for unknown property names' do
      assert_nil service.property_name_mapping('dc:unknownAttribute')
    end

    test 'preload_content_ids returns the id unchanged when it is a uuid' do
      uuid = '00000000-0000-0000-0000-000000000000'

      assert_equal uuid, service.preload_content_ids(uuid)
    end

    test 'preload_content_ids resolves a slug to a thing id' do
      # an unknown slug resolves to nil (no matching translation)
      assert_nil service.preload_content_ids('a-slug-that-does-not-exist')
    end

    test 'allowed_thread_count is computed from the connection pool size' do
      original = ENV.fetch('PUMA_MAX_THREADS', nil)
      ENV.delete('PUMA_MAX_THREADS')

      assert_kind_of Integer, DataCycleCore::ApiService.allowed_thread_count
    ensure
      ENV['PUMA_MAX_THREADS'] = original if original
    end
  end
end
