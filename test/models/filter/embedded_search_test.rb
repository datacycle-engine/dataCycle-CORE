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

      stored_search = DataCycleCore::Search.where(self_contained: true).first
      assert_includes(stored_search.advanced_attributes['float_main'], content.float_main)
      content.embedded_search.each do |embedded_search|
        assert_includes(stored_search.advanced_attributes['float_one'], embedded_search.float_one)
        assert_includes(stored_search.advanced_attributes['float_two'], embedded_search.float_two)
        assert_includes(stored_search.advanced_attributes['float_main'], embedded_search.float_main)
        assert_includes(stored_search.advanced_attributes['integer_main'], embedded_search.integer_main)
        assert_includes(stored_search.advanced_attributes['opens'], embedded_search.opens)
        assert_includes(stored_search.advanced_attributes['closes'], embedded_search.closes)
        assert_includes(stored_search.advanced_attributes['boolean_test'], embedded_search.boolean_test)
        assert_includes(stored_search.advanced_attributes['publish_at'], embedded_search.publish_at.as_json)
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
      stored_search = DataCycleCore::Search.where(self_contained: true).first
      assert_includes(stored_search.advanced_attributes['float_main'], content.float_main)
      content.embedded_search.each do |embedded_search|
        assert_includes(stored_search.advanced_attributes['float_one'], embedded_search.float_one)
        assert_includes(stored_search.advanced_attributes['float_two'], embedded_search.float_two)
        assert_includes(stored_search.advanced_attributes['float_main'], embedded_search.float_main)
        assert_includes(stored_search.advanced_attributes['integer_main'], embedded_search.integer_main)
        assert_includes(stored_search.advanced_attributes['opens'], embedded_search.opens)
        assert_includes(stored_search.advanced_attributes['closes'], embedded_search.closes)
        assert_includes(stored_search.advanced_attributes['boolean_test'], embedded_search.boolean_test)
        assert_includes(stored_search.advanced_attributes['publish_at'], embedded_search.publish_at.as_json)
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
      assert_equal(DataCycleCore::Search.where(self_contained: true).count, 2)

      query = DataCycleCore::Filter::Search.new(locale: [:de])

      test_greater_a = query.equals_advanced_numeric({ min: 7 }, 'float_main')
      assert_equal(1, test_greater_a.count)
      test_greater_b = query.equals_advanced_numeric({ min: 3 }, 'float_main')
      assert_equal(2, test_greater_b.count)
      test_greater_c = query.equals_advanced_numeric({ min: 20 }, 'float_main')
      assert_equal(0, test_greater_c.count)

      test_lower_integer_a = query.equals_advanced_numeric({ max: 8 }, 'integer_main')
      assert_equal(1, test_lower_integer_a.count)
      test_lower_integer_b = query.equals_advanced_numeric({ max: 3 }, 'integer_main')
      assert_equal(0, test_lower_integer_b.count)
      test_lower_integer_c = query.equals_advanced_numeric({ max: 20 }, 'integer_main')
      assert_equal(2, test_lower_integer_c.count)

      test_equals_a = query.equals_advanced_numeric({ min: 4.7, max: 4.7 }, 'float_main')
      assert_equal(1, test_equals_a.count)
      test_equals_b = query.equals_advanced_numeric({ min: 7.21, max: 7.21 }, 'float_main')
      assert_equal(0, test_equals_b.count)

      test_not_equals_a = query.not_equals_advanced_numeric({ min: 4.7, max: 4.7 }, 'float_main')
      assert_equal(1, test_not_equals_a.count)
      test_not_equals_b = query.not_equals_advanced_numeric({ min: 7.21, max: 7.21 }, 'float_main')
      assert_equal(2, test_not_equals_b.count)

      test_between_a = query.equals_advanced_numeric({ min: 3, max: 5 }, 'float_main')
      assert_equal(1, test_between_a.count)
      test_between_b = query.equals_advanced_numeric({ min: 15, max: 20 }, 'float_main')
      assert_equal(0, test_between_b.count)
      test_between_c = query.equals_advanced_numeric({ min: 8, max: 20 }, 'float_main')
      assert_equal(1, test_between_c.count)
      test_between_d = query.equals_advanced_numeric({ min: 5, max: 15 }, 'float_main')
      assert_equal(2, test_between_d.count)

      test_equals_a = query.equals_advanced_numeric({ equals: 3.5 }, 'float_main')
      assert_equal(1, test_equals_a.count)
      test_equals_b = query.equals_advanced_numeric({ equals: 5.8 }, 'float_main')
      assert_equal(1, test_equals_b.count)
      test_equals_c = query.equals_advanced_numeric({ equals: 6.3 }, 'float_main')
      assert_equal(1, test_equals_c.count)
      test_equal_none = query.equals_advanced_numeric({ equals: 6.4 }, 'float_main')
      assert_equal(0, test_equal_none.count)

      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE Numeric 3',
        float_main: 13.7,
        embedded_search: [
          {
            float_main: 19.7,
            integer_main: 9
          },
          {
            float_main: 18.72,
            integer_main: 10
          }
        ]
      })

      test_not_equals_a = query.not_equals_advanced_numeric({ not_equals: 3.5 }, 'float_main')
      assert_equal(2, test_not_equals_a.count)
      test_not_equals_b = query.not_equals_advanced_numeric({ not_equals: 5.8 }, 'float_main')
      assert_equal(2, test_not_equals_b.count)
      test_not_equals_c = query.not_equals_advanced_numeric({ not_equals: 6.3 }, 'float_main')
      assert_equal(2, test_not_equals_c.count)
      test_not_equal_d = query.not_equals_advanced_numeric({ not_equals: 13.7 }, 'float_main')
      assert_equal(1, test_not_equal_d.count)
    end

    test 'test filter for bool values' do
      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE boolean true',
        embedded_search: [
          {
            boolean_test: true
          }
        ]
      })
      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE boolean false',
        embedded_search: [
          {
            boolean_test: false
          }
        ]
      })
      assert_equal(DataCycleCore::Search.where(self_contained: true).count, 2)

      query = DataCycleCore::Filter::Search.new(locale: [:de])

      test_true_a = query.equals_advanced_boolean(true, 'boolean_test')
      assert_equal(1, test_true_a.count)
      assert_equal('HEADLINE boolean true', test_true_a.first.title)
      test_false_a = query.equals_advanced_boolean(false, 'boolean_test')
      assert_equal(1, test_false_a.count)
      assert_equal('HEADLINE boolean false', test_false_a.first.title)
    end

    test 'test filter for time values' do
      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE time a',
        embedded_search: [
          {
            opens: '10:00',
            closes: '21:00'
          }
        ]
      })
      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE time b',
        embedded_search: [
          {
            opens: '17:00',
            closes: '22:00'
          }
        ]
      })
      assert_equal(DataCycleCore::Search.where(self_contained: true).count, 2)

      query = DataCycleCore::Filter::Search.new(locale: [:de])

      # closed after 14:00
      test_closes_a = query.greater_advanced_time('14:00', 'closes')
      assert_equal(2, test_closes_a.count)

      # closed before 14:00
      test_closes_b = query.lower_advanced_time('14:00', 'closes')
      assert_equal(0, test_closes_b.count)

      # opens before 14:00
      test_opens_a = query.lower_advanced_time('14:00', 'opens')
      assert_equal(1, test_opens_a.count)

      # opens before 17:05
      test_opens_b = query.lower_advanced_time('17:05', 'opens')
      assert_equal(2, test_opens_b.count)

      # opens between 9:00 and 11:00
      test_between_a = query.greater_advanced_time('09:00', 'opens').lower_advanced_time('11:00', 'opens')
      assert_equal(1, test_between_a.count)
      assert_equal('HEADLINE time a', test_between_a.first.title)

      # is open at 12:00
      test_between_b = query.greater_advanced_time('12:00', 'closes').lower_advanced_time('12:00', 'opens')
      assert_equal(1, test_between_b.count)
      assert_equal('HEADLINE time a', test_between_b.first.title)

      # is open at 21:00
      test_between_b = query.greater_advanced_time('21:00', 'closes').lower_advanced_time('21:00', 'opens')
      assert_equal(1, test_between_b.count)
      assert_equal('HEADLINE time b', test_between_b.first.title)

      # opens exactly at 17:00
      test_opens_exactly_a = query.equals_advanced_time('17:00', 'opens')
      assert_equal(1, test_opens_exactly_a.count)

      # opens exactly at 15:00
      test_opens_exactly_b = query.equals_advanced_time('15:00', 'opens')
      assert_equal(0, test_opens_exactly_b.count)

      # not opens exactly at 17:00
      test_opens_exactly_a = query.not_equals_advanced_time('17:00', 'opens')
      assert_equal(1, test_opens_exactly_a.count)

      # not opens exactly at 15:00
      test_opens_exactly_b = query.not_equals_advanced_time('15:00', 'opens')
      assert_equal(2, test_opens_exactly_b.count)
    end

    test 'test filter for date values' do
      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE date a',
        embedded_search: [
          {
            publish_at: '2019-10-10'
          }
        ]
      })
      DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE date b',
        embedded_search: [
          {
            publish_at: '2019-10-29'
          }
        ]
      })
      assert_equal(DataCycleCore::Search.where(self_contained: true).count, 2)

      query = DataCycleCore::Filter::Search.new(locale: [:de])

      test_greater_date_a = query.equals_advanced_date({ from: '2019-10-01' }, 'publish_at')
      assert_equal(2, test_greater_date_a.count)
      test_greater_date_b = query.equals_advanced_date({ from: '2019-10-11' }, 'publish_at')
      assert_equal(1, test_greater_date_b.count)
      test_greater_date_c = query.equals_advanced_date({ from: '2019-10-30' }, 'publish_at')
      assert_equal(0, test_greater_date_c.count)

      test_lower_date_a = query.equals_advanced_date({ until: '2019-10-01' }, 'publish_at')
      assert_equal(0, test_lower_date_a.count)
      test_lower_date_b = query.equals_advanced_date({ until: '2019-10-27' }, 'publish_at')
      assert_equal(1, test_lower_date_b.count)
      test_lower_date_c = query.equals_advanced_date({ until: '2019-10-29' }, 'publish_at')
      assert_equal(2, test_lower_date_c.count)

      test_equals_date_a = query.equals_advanced_date({ from: '2019-10-01', until: '2019-10-01' }, 'publish_at')
      assert_equal(0, test_equals_date_a.count)
      test_equals_date_b = query.equals_advanced_date({ from: '2019-10-29', until: '2019-10-29' }, 'publish_at')
      assert_equal(1, test_equals_date_b.count)

      test_not_equals_date_a = query.not_equals_advanced_date({ from: '2019-10-01', until: '2019-10-01' }, 'publish_at')
      assert_equal(2, test_not_equals_date_a.count)
      test_not_equals_date_b = query.not_equals_advanced_date({ from: '2019-10-29', until: '2019-10-29' }, 'publish_at')
      assert_equal(1, test_not_equals_date_b.count)

      test_between_date_a = query.equals_advanced_date({ from: '2019-10-01', until: '2019-11-01' }, 'publish_at')
      assert_equal(2, test_between_date_a.count)
      test_between_date_b = query.equals_advanced_date({ from: '2019-10-11', until: '2019-11-01' }, 'publish_at')
      assert_equal(1, test_between_date_b.count)
      assert_equal('HEADLINE date b', test_between_date_b.first.title)
      test_between_date_c = query.equals_advanced_date({ from: '2019-10-30', until: '2019-11-01' }, 'publish_at')
      assert_equal(0, test_between_date_c.count)
    end
  end
end
