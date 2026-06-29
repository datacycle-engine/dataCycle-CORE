# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class BaseTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Base
        end

        test 'equals? compares two values' do
          assert(subject.equals?('a', 'a'))
          assert_not(subject.equals?('a', 'b'))
        end

        test 'exists? checks for presence' do
          assert(subject.exists?('value', nil))
          assert_not(subject.exists?('', nil))
          assert_not(subject.exists?(nil, nil))
        end

        test 'condition_satisfied? reads from the external source default options' do
          content = struct_double(external_source: struct_double(default_options: { 'channel' => 'feratel' }))
          definition = { 'type' => 'external_source', 'name' => 'channel', 'method' => 'equals?', 'value' => 'feratel' }

          assert(subject.condition_satisfied?(content, definition, nil))
        end

        test 'condition_satisfied? reads an I18n value' do
          definition = { 'type' => 'I18n', 'name' => 'locale', 'method' => 'exists?' }

          assert(subject.condition_satisfied?(nil, definition, nil))
        end

        test 'condition_satisfied? evaluates an allowed current_user method' do
          definition = { 'type' => 'current_user', 'name' => 'present?', 'method' => 'equals?', 'value' => true }

          assert(subject.condition_satisfied?(nil, definition, struct_double(id: 1)))
        end

        test 'condition_satisfied? raises for an unknown current_user method' do
          definition = { 'type' => 'current_user', 'name' => 'destroy', 'method' => 'equals?', 'value' => true }

          error = assert_raises(RuntimeError) { subject.condition_satisfied?(nil, definition, struct_double(id: 1)) }
          assert_equal('unknown method for current_user', error.message)
        end

        test 'condition_satisfied? raises for an unknown type' do
          definition = { 'type' => 'bogus', 'name' => 'x', 'method' => 'equals?' }

          error = assert_raises(RuntimeError) { subject.condition_satisfied?(nil, definition, nil) }
          assert_equal('Unknown type for validation', error.message)
        end
      end
    end
  end
end
