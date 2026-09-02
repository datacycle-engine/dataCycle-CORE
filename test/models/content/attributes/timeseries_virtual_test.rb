# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class TimeseriesVirtualTest < ActiveSupport::TestCase
        setup do
          @timeseries = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Series 1' })
          0.upto(10) do |i|
            DataCycleCore::Timeseries.create(thing_id: @timeseries.id, property: 'series', timestamp: Time.zone.now, value: i)
          end
        end

        def virtual_value(name, thing)
          thing.load_virtual_attribute(name)
        end

        test 'Testing Utility::Virtual::Timeseries methods' do
          assert_equal(0, @timeseries.series_first)
          assert_equal(10, @timeseries.series_last)
          assert_equal(0, virtual_value('series_first', @timeseries))
          assert_equal(10, virtual_value('series_last', @timeseries))

          assert_equal(0, @timeseries.series_min)
          assert_equal(10, @timeseries.series_max)
          assert_equal(0, virtual_value('series_min', @timeseries))
          assert_equal(10, virtual_value('series_max', @timeseries))

          assert_equal(11, @timeseries.series_count)
          assert_equal(55, @timeseries.series_sum)
          assert_equal(5, @timeseries.series_avg)
          assert_equal(11, virtual_value('series_count', @timeseries))
          assert_equal(55, virtual_value('series_sum', @timeseries))
          assert_equal(5, virtual_value('series_avg', @timeseries))
        end

        test 'aggregate virtuals stay accurate on a collapsed series (Redmine #39891)' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Collapsed aggregates' })
          base = Time.zone.now

          # 5 raw datapoints, all value 3, collapse down to 2 physical rows
          DataCycleCore::Timeseries::RedundantValueCollapser.new(thing_id: content.id, property: 'series_collapsed').call(
            Array.new(5) { |i| { timestamp: base + i.minutes, value: 3 } }
          )

          assert_equal 2, DataCycleCore::Timeseries.where(thing_id: content.id, property: 'series_collapsed').count

          assert_equal(5, content.series_collapsed_count)
          assert_equal(15, content.series_collapsed_sum)
          assert_equal(3, content.series_collapsed_avg)
        end

        test 'count/avg skip NULL-value rows on a non-collapsing series, same as the old COUNT(value)/AVG(value)' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Null values' })
          base = Time.zone.now

          DataCycleCore::Timeseries.create!(thing_id: content.id, property: 'series', timestamp: base, value: 10)
          DataCycleCore::Timeseries.create!(thing_id: content.id, property: 'series', timestamp: base + 1.minute, value: nil)
          DataCycleCore::Timeseries.create!(thing_id: content.id, property: 'series', timestamp: base + 2.minutes, value: 20)

          assert_equal(2, content.series_count)
          assert_equal(30, content.series_sum)
          assert_equal(15, content.series_avg)
        end
      end
    end
  end
end
