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
      end
    end
  end
end
