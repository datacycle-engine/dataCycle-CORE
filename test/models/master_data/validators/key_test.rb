# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Key do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Key
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'id',
        'type' => 'key'
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates a key' do
      key_object = '00000000-0000-0000-0000-000000000000'
      assert_equal(no_error_hash, subject.new(key_object, template_hash).error)
    end

    it 'rejects arbitrary objects' do
      test_cases = [10, :wednesday, 'servus']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    # it 'produces a warning when nil is given as key' do
    #   validator = subject.new(nil, template_hash)
    #   assert_equal(0, validator.error[:error].size)
    #   assert_equal(1, validator.error[:warning].size)
    # end

    it 'accepts different boolean objects' do
      test_cases = ['00000000-0000-0000-0000-000000000000', ' 00000000-0000-0000-0000-000000000000  ']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end
  end
end
