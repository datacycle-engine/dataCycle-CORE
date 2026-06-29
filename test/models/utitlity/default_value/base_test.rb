# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DefaultValue
      class BaseTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::DefaultValue::Base
        end

        test 'condition_user checks the configured rank against the user' do
          user = Class.new { def is_rank?(_rank) = true }.new # rubocop:disable Naming/PredicatePrefix -- mirrors the production User#is_rank? name

          assert(subject.send(:condition_user, user, { 'rank' => 2 }, nil))
        end

        test 'condition_user returns nil when no rank is configured' do
          assert_nil(subject.send(:condition_user, nil, {}, nil))
        end

        test 'condition_except_content_type compares the content type against the configured value' do
          assert(subject.send(:condition_except_content_type, nil, 'Artikel', struct_double(content_type: 'Event')))
          assert_not(subject.send(:condition_except_content_type, nil, 'Artikel', struct_double(content_type: 'Artikel')))
        end

        test 'condition_schema_key_present checks the schema for the configured key' do
          content = struct_double(schema: { 'name' => {} })

          assert(subject.send(:condition_schema_key_present, nil, 'name', content))
          assert_not(subject.send(:condition_schema_key_present, nil, 'missing', content))
        end

        test 'skip_default_value? resolves missing default-value dependencies before re-checking' do
          content = Class.new {
            def default_value_property_names = ['dependency']
            def properties_for(_key) = nil
          }.new
          data_hash = {}

          result = subject.send(:skip_default_value?, 'main', data_hash, content, ['dependency'], nil, false, false)

          assert(result)
        end
      end
    end
  end
end
