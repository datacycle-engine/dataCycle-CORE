# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DefaultValue
      class BooleanTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::DefaultValue::Boolean
        end

        test 'default returns the configured value' do
          assert_equal('configured', subject.default(property_definition: { default_value: { value: 'configured' } }))
          assert(subject.default(property_definition: { default_value: { value: true } }))
        end

        test 'default falls back to false when no value is configured' do
          assert_not(subject.default(property_definition: { default_value: {} }))
          assert_not(subject.default(property_definition: nil))
        end
      end
    end
  end
end
