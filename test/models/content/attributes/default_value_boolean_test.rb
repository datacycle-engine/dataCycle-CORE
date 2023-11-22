# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueBooleanTest < ActiveSupport::TestCase
        def set_default_value(template_name, key, value, content = nil)
          template = content || DataCycleCore::ThingTemplate.find_by(template_name:)

          if value.blank?
            template.schema['properties'][key].delete('default_value')
          else
            template.schema['properties'][key]['default_value'] = value
          end

          template.update_column(:schema, template.schema) if template.is_a?(DataCycleCore::ThingTemplate)
          template.remove_instance_variable(:@default_value_property_names) if template.instance_variable_defined?(:@default_value_property_names)
        end

        test 'default booleans get set on new contents' do
          set_default_value('SimpleJsonTest', 'bool', 'true')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'SimpleJsonTest', data_hash: { name: 'Test SimpleJsonTest 1' })

          assert_equal true, content.bool
        end

        test 'default booleans dont override existing values on new contents' do
          set_default_value('SimpleJsonTest', 'bool', 'true')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'SimpleJsonTest', data_hash: { name: 'Test SimpleJsonTest 1', bool: 'false' })

          assert_equal false, content.bool
        end

        test 'default booleans dont override existing false boolean values on new contents' do
          set_default_value('SimpleJsonTest', 'bool', 'true')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'SimpleJsonTest', data_hash: { name: 'Test SimpleJsonTest 1', bool: false })

          assert_equal false, content.bool
        end

        test 'default booleans dont override existing true boolean values on new contents' do
          set_default_value('SimpleJsonTest', 'bool', 'false')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'SimpleJsonTest', data_hash: { name: 'Test SimpleJsonTest 1', bool: true })

          assert_equal true, content.bool
        end

        test 'default booleans get overriden by blank values on existing contents with partial update' do
          set_default_value('SimpleJsonTest', 'bool', 'true')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'SimpleJsonTest', data_hash: { name: 'Test SimpleJsonTest 1' })

          assert_equal true, content.bool

          content.set_data_hash(data_hash: { name: 'Test SimpleJsonTest 2', bool: nil }, update_search_all: false, prevent_history: true, partial_update: true)

          assert_nil content.bool
          assert_equal 'Test SimpleJsonTest 2', content.name
        end
      end
    end
  end
end
