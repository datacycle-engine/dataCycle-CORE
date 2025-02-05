# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class IncludedSearchTest < ActiveSupport::TestCase
    test 'make sure included objectsa added correctly' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Included-Entity-Search', data_hash: {
        name: 'HEADLINE 1',
        description: 'DESCRIPTION 1',
        float_main: 7.1,
        validity_period: {
          valid_from: '2019-10-10',
          valid_until: '2019-10-27'
        },
        embedded_search: [
          {
            name: 'HEADLINE Search 1',
            description: 'DESCRIPTION Search 1',
            float_main: 3.1,
            validity_period: {
              valid_from: '2019-10-11',
              valid_until: '2019-10-17'
            }
          },
          {
            name: 'HEADLINE Search 2',
            description: 'DESCRIPTION Search 2',
            float_main: 6,
            validity_period: {
              valid_from: '2019-10-18',
              valid_until: '2019-10-23'
            }
          }
        ]
      })

      stored_search = DataCycleCore::Search.where(self_contained: true).first

      assert_includes(stored_search.advanced_attributes['float_main'], content.float_main)
      assert_includes(stored_search.advanced_attributes['validity_period.valid_until'], content.validity_period.valid_until.as_json)
      assert_includes(stored_search.advanced_attributes['validity_period.valid_until'], content.validity_period.valid_until.as_json)
      content.embedded_search.each do |embedded_search|
        assert_includes(stored_search.advanced_attributes['float_main'], embedded_search.float_main)
        assert_includes(stored_search.advanced_attributes['validity_period.valid_until'], content.validity_period.valid_until.as_json)
        assert_includes(stored_search.advanced_attributes['validity_period.valid_until'], content.validity_period.valid_until.as_json)
      end
    end
  end
end
