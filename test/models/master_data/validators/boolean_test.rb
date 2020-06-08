# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Boolean do
  subject do
    DataCycleCore::MasterData::Validators::Boolean
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'boolean',
        'storage_location' => 'translated_value'
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates a bool' do
      date_object = true
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

    it 'accepts different boolean objects' do
      test_cases = [true, false, 'true', 'false', '    true     ']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end
  end
end
