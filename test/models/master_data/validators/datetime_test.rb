require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Datetime do
  subject do
    DataCycleCore::MasterData::Validators::Datetime
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'datetime',
        'storage_location' => 'translated_value'
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates a DateObject' do
      date_object = '2010-01-01'.to_datetime
      assert_equal(no_error_hash, subject.new(date_object, template_hash).error)
    end

    it 'rejects arbitrary objects' do
      test_cases = [10, :wednesday]
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'converts unexpected strings to dates' do
      test_cases = ['10', '10.10.10.10.']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'accepts different Date, DateTime objects' do
      test_cases = [
        Time.now,
        Time.zone.now,
        '01.01.2000'.to_datetime,
        '01.01.2000'.to_date,
        Date.new(2000).in_time_zone,
        Time.utc(2000).in_time_zone
      ]
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end
  end
end
