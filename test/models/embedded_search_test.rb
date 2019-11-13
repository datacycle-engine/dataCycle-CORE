# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedSearchTest < ActiveSupport::TestCase
    def setup
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE 1',
        description: 'DESCRIPTION 1',
        float_main: 7.1,
        embedded_search: [
          {
            name: 'HEADLINE Search 1',
            description: 'DESCRIPTION Search 1',
            float_one: 12.3,
            float_two: 36.8,
            float_main: 5,
            integer_main: 3,
            opens: '12:00',
            closes: '23:00',
            publish_at: '2019-10-10',
            boolean_test: true
          },
          {
            name: 'HEADLINE Search 2',
            description: 'DESCRIPTION Search 2',
            float_one: 1.3,
            float_two: 1000,
            float_main: 6,
            integer_main: 7,
            opens: '13:00',
            closes: '17:00',
            publish_at: '2019-12-12',
            boolean_test: false
          }
        ]
      })
    end

    test 'make sure advanced_search attributes added correctly' do
      stored_search = DataCycleCore::Search.first
      assert_includes(stored_search.advanced_attributes.dig('float_main'), @content.float_main)
      @content.embedded_search.each do |embedded_search|
        assert_includes(stored_search.advanced_attributes.dig('float_one'), embedded_search.float_one)
        assert_includes(stored_search.advanced_attributes.dig('float_two'), embedded_search.float_two)
        assert_includes(stored_search.advanced_attributes.dig('float_main'), embedded_search.float_main)
        assert_includes(stored_search.advanced_attributes.dig('integer_main'), embedded_search.integer_main)
        assert_includes(stored_search.advanced_attributes.dig('opens'), embedded_search.opens)
        assert_includes(stored_search.advanced_attributes.dig('closes'), embedded_search.closes)
        assert_includes(stored_search.advanced_attributes.dig('boolean_test'), embedded_search.boolean_test)
        assert_includes(stored_search.advanced_attributes.dig('publish_at'), embedded_search.publish_at.as_json)
      end
    end
  end
end
