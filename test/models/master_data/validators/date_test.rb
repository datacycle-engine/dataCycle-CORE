# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Date do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Date
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'date',
        'storage_location' => 'translated_value'
      }
    end

    let(:template_hash2) do
      {
        'label' => 'Test',
        'type' => 'date',
        'storage_location' => 'translated_value',
        'validations' => {
          'min' => '01.01.2018'
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates a DateObject' do
      date_object = '2010-01-01'.to_date
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

    it 'accepts different Date objects' do
      test_cases = [
        Date.current,
        Time.current.to_date,
        '01.01.2018'.to_date,
        '1-1-2018'.to_date
      ]
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'accepts dates after specified min date' do
      test_cases = [Date.current, Time.current.to_date, '01.01.2019']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash2)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'rejects dates before specified min date' do
      test_cases = ['01.01.2017'.to_date, '01.01.2017'.in_time_zone.to_date, '01.01.2017']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash2)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'produces no warning when an unsupported keyword is used' do
      new_template = template_hash2.deep_dup.merge({ 'validations' => { 'maxi' => 3 } })
      validator = subject.new(Date.current, new_template)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end
  end
end
