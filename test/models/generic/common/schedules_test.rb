# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::Transformations::Schedules do
  include DataCycleCore::MinitestSpecHelper

  subject { DataCycleCore::Generic::Common::Transformations::Schedules }

  let(:external_source_id) { '11111111-1111-1111-1111-111111111111' }

  it 'builds an event_schedule from a single occurrence' do
    data = { 'startDate' => '2024-01-01T10:00:00', 'endDate' => '2024-01-01T12:00:00', 'external_key' => 'EK' }
    result = subject.add_schedule_from_single_occurrence(data, external_source_id)

    assert_equal(1, result['event_schedule'].size)
    schedule = result['event_schedule'].first

    assert_equal(external_source_id, schedule[:external_source_id])
    assert_in_delta(7200.0, schedule[:duration])
  end

  it 'returns an empty event_schedule when the dates are blank' do
    result = subject.add_schedule_from_single_occurrence({ 'external_key' => 'EK' }, external_source_id)

    assert_equal([], result['event_schedule'])
  end

  it 'returns an empty event_schedule when start is after end' do
    data = { 'startDate' => '2024-01-01T12:00:00', 'endDate' => '2024-01-01T10:00:00' }
    result = subject.add_schedule_from_single_occurrence(data, external_source_id)

    assert_equal([], result['event_schedule'])
  end
end
