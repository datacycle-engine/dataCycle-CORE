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
      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
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
      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
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

      test_greater_a = query.greater_advanced_numeric(7, 'float_main')
      assert_equal(test_greater_a.count, 1)
      test_greater_b = query.greater_advanced_numeric(3, 'float_main')
      assert_equal(test_greater_b.count, 2)
      test_greater_c = query.greater_advanced_numeric(20, 'float_main')
      assert_equal(test_greater_c.count, 0)

      test_greater_integer_a = query.greater_advanced_numeric(8, 'integer_main')
      assert_equal(test_greater_integer_a.count, 1)
      test_greater_integer_b = query.greater_advanced_numeric(3, 'integer_main')
      assert_equal(test_greater_integer_b.count, 2)
      test_greater_integer_c = query.greater_advanced_numeric(20, 'integer_main')
      assert_equal(test_greater_integer_c.count, 0)

      test_greater_integer_a = query.greater_advanced_numeric(8, 'integer_main')
      assert_equal(test_greater_integer_a.count, 1)
      test_greater_integer_b = query.greater_advanced_numeric(3, 'integer_main')
      assert_equal(test_greater_integer_b.count, 2)
      test_greater_integer_c = query.greater_advanced_numeric(20, 'integer_main')
      assert_equal(test_greater_integer_c.count, 0)

      test_equals_a = query.equals_advanced_numeric(4.7, 'float_main')
      assert_equal(test_equals_a.count, 1)
      test_equals_b = query.equals_advanced_numeric(7.21, 'float_main')
      assert_equal(test_equals_b.count, 0)

      test_not_equals_a = query.not_equals_advanced_numeric(4.7, 'float_main')
      assert_equal(test_not_equals_a.count, 2)
      test_not_equals_b = query.not_equals_advanced_numeric(7.21, 'float_main')
      assert_equal(test_not_equals_b.count, 2)

      test_between_a = query.greater_advanced_numeric(3, 'float_main').lower_advanced_numeric(5, 'float_main')
      assert_equal(test_between_a.count, 1)
      test_between_b = query.greater_advanced_numeric(15, 'float_main').lower_advanced_numeric(20, 'float_main')
      assert_equal(test_between_b.count, 0)
      test_between_c = query.greater_advanced_numeric(8, 'float_main').lower_advanced_numeric(10, 'float_main')
      assert_equal(test_between_c.count, 1)
      test_between_d = query.greater_advanced_numeric(5, 'float_main').lower_advanced_numeric(15, 'float_main')
      assert_equal(test_between_d.count, 2)
    end
  end
end
