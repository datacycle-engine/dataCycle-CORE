# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueEmbeddedTest < ActiveSupport::TestCase
        test 'default values for GIP Waypoints in Route Descriptions get set on new contents' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Radroutenbeschreibung', data_hash: { name: 'Test Radroutenbeschreibung 1' })
          assert content.try('way_point').to_a.select { |wp| wp.name == 'Start' }.present?
          assert content.try('way_point').to_a.select { |wp| wp.name == 'Ende' }.present?
        end
      end
    end
  end
end
