# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedSearchTest < ActiveSupport::TestCase
    test 'make sure advanced_search attributes added and updated correctly' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
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

      stored_search = DataCycleCore::Search.first
      assert_includes(stored_search.advanced_attributes.dig('float_main'), content.float_main)
      content.embedded_search.each do |embedded_search|
        assert_includes(stored_search.advanced_attributes.dig('float_one'), embedded_search.float_one)
        assert_includes(stored_search.advanced_attributes.dig('float_two'), embedded_search.float_two)
        assert_includes(stored_search.advanced_attributes.dig('float_main'), embedded_search.float_main)
        assert_includes(stored_search.advanced_attributes.dig('integer_main'), embedded_search.integer_main)
        assert_includes(stored_search.advanced_attributes.dig('opens'), embedded_search.opens)
        assert_includes(stored_search.advanced_attributes.dig('closes'), embedded_search.closes)
        assert_includes(stored_search.advanced_attributes.dig('boolean_test'), embedded_search.boolean_test)
        assert_includes(stored_search.advanced_attributes.dig('publish_at'), embedded_search.publish_at.as_json)
      end

      content.set_data_hash(data_hash: content.get_data_hash.merge(
        {
          float_main: 2.3,
          embedded_search: [
            {
              name: 'HEADLINE Search 1 - New',
              description: 'DESCRIPTION Search 1 - New',
              float_one: 12.7,
              float_two: 36.5,
              float_main: 3,
              integer_main: 2,
              opens: '10:00',
              closes: '21:00',
              publish_at: '2020-10-10',
              boolean_test: true
            },
            {
              name: 'HEADLINE Search 2 - New',
              description: 'DESCRIPTION Search 2 - New',
              float_one: 1.4,
              float_two: 10,
              float_main: 60,
              integer_main: 7,
              opens: '11:00',
              closes: '17:00',
              publish_at: '2019-12-12',
              boolean_test: false
            }
          ]
        }
      ))
      stored_search = DataCycleCore::Search.first
      assert_includes(stored_search.advanced_attributes.dig('float_main'), content.float_main)
      content.embedded_search.each do |embedded_search|
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

    test 'test filter for numeric values' do
      content_a = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE Numeric',
        float_main: 3.5,
        embedded_search: [
          {
            float_main: 4.7,
            integer_main: 7
          },
          {
            float_main: 6.3,
            integer_main: 8
          }
        ]
      })
      content_b = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE Numeric 2',
        float_main: 5.8,
        embedded_search: [
          {
            float_main: 8.7,
            integer_main: 9
          },
          {
            float_main: 13.7,
            integer_main: 10
          }
        ]
      })
      assert_equal(DataCycleCore::Search.count, 2)

      filter = DataCycleCore::StoredFilter.new
      filter.language = ['de']
      query = filter.apply


      test = query.greater_advanced_numeric(7,'float_main')
      byebug
    end
  end
end
