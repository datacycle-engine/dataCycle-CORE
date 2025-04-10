# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DashboardScheduleSortTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    include Engine.routes.url_helpers

    before(:all) do
      DataCycleCore::Thing.delete_all
      @routes = Engine.routes
      current_ts = Time.zone.now

      @event_d = DataCycleCore::DummyDataHelper.event
      @event_d.set_data_hash(partial_update: true, prevent_history: true, data_hash:
        {
          name: 'D',
          event_schedule: [
            DataCycleCore::TestPreparations.generate_schedule(
              0.months.ago.beginning_of_week.midday + 0.days,
              4.months.from_now,
              1.hour,
              frequency: 'weekly'
            ).serialize_schedule_object.schedule_object.to_hash
          ]
        })
      @event_d.update_column(:created_at, current_ts+1.minute)
      @event_d.update_column(:updated_at, current_ts+1.minute)

      @event_c = DataCycleCore::DummyDataHelper.event
      @event_c.set_data_hash(partial_update: true, prevent_history: true, data_hash:
        {
          name: 'C',
          event_schedule: [
            DataCycleCore::TestPreparations.generate_schedule(
              1.month.ago.beginning_of_week.midday + 1.day,
              3.months.from_now,
              0.hours,
              frequency: 'weekly'
            ).serialize_schedule_object.schedule_object.to_hash
          ]
        })        
      @event_c.update_column(:created_at, current_ts+2.minutes)
      @event_c.update_column(:updated_at, current_ts+2.minutes)

      @event_b = DataCycleCore::DummyDataHelper.event
      @event_b.set_data_hash(partial_update: true, prevent_history: true, data_hash:
        {
          name: 'B',
          event_schedule: [
            DataCycleCore::TestPreparations.generate_schedule(
              2.months.ago.beginning_of_week.midday + 2.days,
              2.months.from_now,
              1.hour,
              frequency: 'weekly'
            ).serialize_schedule_object.schedule_object.to_hash
          ]
        })
      @event_b.update_column(:created_at, current_ts+3.minutes)
      @event_b.update_column(:updated_at, current_ts+3.minutes)

      @event_a = DataCycleCore::DummyDataHelper.event
      @event_a.set_data_hash(partial_update: true, prevent_history: true, data_hash:
        {
          name: 'A',
          event_schedule: [
            DataCycleCore::TestPreparations.generate_schedule(
              3.months.ago.beginning_of_week.midday + 3.days,
              1.month.from_now,
              2.hours,
              frequency: 'weekly'
            ).serialize_schedule_object.schedule_object.to_hash
          ]
        })
      @event_a.update_column(:created_at, current_ts+4.minutes)
      @event_a.update_column(:updated_at, current_ts+4.minutes)

      @poi = DataCycleCore::DummyDataHelper.poi
      @poi.set_data_hash(partial_update: true, prevent_history: true, data_hash:
        {
          name: 'POI',
          opening_hours_specification: [
            DataCycleCore::TestPreparations.generate_schedule(
              3.months.ago.beginning_of_week.midday + 4.days,
              1.month.from_now,
              2.hours,
              frequency: 'weekly'
            ).serialize_schedule_object.schedule_object.to_hash
          ]
        })
      @poi.update_column(:created_at, current_ts+5.minutes)
      @poi.update_column(:updated_at, current_ts+5.minutes)

      DataCycleCore::Thing.where(template_name: 'Bild').delete_all

      @from =  Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601)
      @to = Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
    end

    test 'filter event_schedule with sort_created_at' do
      filter_params = [{"c"=>"a", "t"=>"in_schedule", "q"=>"absolute", "m"=>"i", "n"=>"event_schedule", "v"=>{"from"=>@from, "until"=>@until}}]
      sort_params =[{"o"=>"ASC", "m"=>"created_at"}]
    
      stored_filter = DataCycleCore::StoredFilter.new
      stored_filter.apply_sorting_from_parameters(sort_params: sort_params, filters: filter_params)
      query = stored_filter.things
     
      things = [@event_d, @event_c, @event_b, @event_a]
      things.zip(query).each_with_index do |(expected, actual), i|
        assert_equal(expected.id, actual.id)
      end
    end

    test 'filter opening_hours_specification with sort modified_at' do
      filter_params = [{"c"=>"a", "t"=>"in_schedule", "q"=>"absolute", "m"=>"i", "n"=>"event_schedule", "v"=>{"from"=>@from, "until"=>@until}}]
      sort_params =[{"o"=>"ASC", "m"=>"modified_at"}]
      
      stored_filter = DataCycleCore::StoredFilter.new
      stored_filter.apply_sorting_from_parameters(sort_params: sort_params, filters: filter_params)
      query = stored_filter.things

      things = [@event_d, @event_c, @event_b, @event_a]
      things.zip(query).each_with_index do |(expected, actual), i|
        assert_equal(expected.id, actual.id)
      end
    end

    test 'filter opening_hours_specification with sort name' do
      filter_params = [{"c"=>"a", "t"=>"in_schedule", "q"=>"absolute", "m"=>"i", "n"=>"event_schedule", "v"=>{"from"=>@from, "until"=>@until}}]
      sort_params =[{"o"=>"ASC", "m"=>"name"}]
      
      stored_filter = DataCycleCore::StoredFilter.new
      stored_filter.apply_sorting_from_parameters(sort_params: sort_params, filters: filter_params)
      query = stored_filter.things

      things = [@event_a, @event_b, @event_c, @event_d]
      things.zip(query).each_with_index do |(expected, actual), i|
        assert_equal(expected.id, actual.id)
      end
    end

    test 'filter opening_hours_specification with sort default' do
      filter_params = [{"c"=>"a", "t"=>"in_schedule", "q"=>"absolute", "m"=>"i", "n"=>"opening_hours_specification", "v"=>{"from"=>@from, "until"=>@until}}]
      
      stored_filter = DataCycleCore::StoredFilter.new
      stored_filter.apply_sorting_from_parameters(sort_params: nil, filters: filter_params)
      query = stored_filter.things

      things = [@poi]
      things.zip(query).each_with_index do |(expected, actual), i|
        assert_equal(expected.id, actual.id)
      end
    end

    test 'filter event_schedule with sort default' do
      filter_params = [{"c"=>"a", "t"=>"in_schedule", "q"=>"absolute", "m"=>"i", "n"=>"event_schedule", "v"=>{"from"=>@from, "until"=>@until}}]
      
      stored_filter = DataCycleCore::StoredFilter.new
      stored_filter.apply_sorting_from_parameters(sort_params: nil, filters: filter_params)
      query = stored_filter.things

      things = [@event_d, @event_c, @event_b, @event_a]
      things.zip(query).each_with_index do |(expected, actual), i|
        assert_equal(expected.id, actual.id)
      end
    end
  end
end
