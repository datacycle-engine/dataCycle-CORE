# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueEmbeddedTest < ActiveSupport::TestCase
        test 'default values for GIP Waypoints in Route Descriptions get set on new contents' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-With-Start-End-Default-Values', data_hash: { name: 'Test' })
          assert(content.try('embedded_creative_work').to_a.any? { |wp| wp.name == 'Start' })
          assert(content.try('embedded_creative_work').to_a.any? { |wp| wp.name == 'Ende' })
        end
      end
    end
  end
end
