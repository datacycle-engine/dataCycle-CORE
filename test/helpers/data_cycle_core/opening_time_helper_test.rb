# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class OpeningTimeHelperTest < ActionView::TestCase
    include DataCycleCore::OpeningTimeHelper
    include DataCycleCore::UiLocaleHelper

    test 'opening_time_time_definition returns the base definition' do
      definition = opening_time_time_definition

      assert_equal 'opening_time_time', definition['type']
      assert_equal 'Zeit', definition['label']
      assert_not definition.key?('ui')
    end

    test 'opening_time_time_definition marks the field readonly when requested' do
      assert_equal({ 'edit' => { 'readonly' => true } }, opening_time_time_definition(readonly: true)['ui'])
    end

    test 'opening_time_opens and opening_time_closes return nil for a blank hash' do
      assert_nil opening_time_opens(nil)
      assert_nil opening_time_closes(nil)
    end

    test 'opening_time_opens normalizes the start time to the current year' do
      result = opening_time_opens({ start_time: { time: Time.zone.local(2024, 1, 15, 9, 30), zone: nil } })

      assert_equal [9, 30], [result.hour, result.min]
    end

    test 'opening_time_closes without a duration matches the start time' do
      result = opening_time_closes({ start_time: { time: Time.zone.local(2024, 1, 15, 9, 30), zone: nil } })

      assert_equal [9, 30], [result.hour, result.min]
    end

    test 'opening_time_validity_period renders the from/until range' do
      html = opening_time_validity_period([Time.zone.local(2024, 1, 15), Time.zone.local(2024, 12, 31)])

      assert_includes html, '15.01.2024'
      assert_includes html, '31.12.2024'
      assert_predicate html, :html_safe?
    end

    test 'opening_time_ex_dates returns nil without exception times' do
      assert_nil opening_time_ex_dates([{}])
    end

    test 'opening_time_ex_dates lists the exception dates' do
      html = opening_time_ex_dates([{ extimes: [{ time: Time.zone.local(2024, 3, 1, 12, 0) }] }])

      assert_includes html, '01.03.2024'
      assert_predicate html, :html_safe?
    end

    test 'opening_time_opening_hours renders every weekday as closed when there are no rules' do
      html = opening_time_opening_hours([])

      assert_predicate html, :html_safe?
      assert_includes html, 'Montag'
      assert_includes html, 'geschlossen'
    end
  end
end
