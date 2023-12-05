# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueDateTest < ActiveSupport::TestCase
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

        test 'default dates get set on new contents' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })

          assert_equal Date.current, content.upload_date
        end
      end
    end
  end
end
