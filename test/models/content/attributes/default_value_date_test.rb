# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueDateTest < ActiveSupport::TestCase
        def set_default_value(template_name, key, value, content = nil)
          template = content || DataCycleCore::Thing.find_by(template: true, template_name: template_name)
          template.schema['properties'][key]['default_value'] = value
          template.save
        end

        test 'default dates get set on new contents' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })

          assert_equal Date.current, content.upload_date
        end
      end
    end
  end
end
