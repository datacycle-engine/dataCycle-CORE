# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Number do
  subject do
    DataCycleCore::MasterData::Validators::Number
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'number',
        'storage_location' => 'translated_value'
      }
    end

    let(:template_hash_val) do
      {
        'label' => 'Test',
        'type' => 'number',
        'storage_location' => 'translated_value',
        'validations' => {
          'min' => 3,
          'max' => 100,
          'format' => 'float'
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates integer' do
      assert_equal(no_error_hash, subject.new(10, template_hash).error)
    end

    it 'rejects strings' do
      validator = subject.new('10', template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    # it 'warns if no data is given' do
    #   validator = subject.new(nil, template_hash)
    #   assert_equal(0, validator.error[:error].size)
    #   assert_equal(1, validator.error[:warning].size)
    # end

    it 'succeeds if number is given within min, max options' do
      validator = subject.new(50.55, template_hash_val)
      assert_equal(no_error_hash, validator.error)
    end

    it 'errors out when number < min' do
      validator = subject.new(1, template_hash_val)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when number > max' do
      validator = subject.new(500, template_hash_val)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when unsuppoted format is given' do
      new_hash = template_hash.deep_dup
      new_hash['validations'] = { 'format' => 'xxx' }
      validator = subject.new(5.333, new_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when format is violated' do
      new_hash = template_hash.deep_dup
      new_hash['validations'] = { 'format' => 'integer' }
      validator = subject.new(5.333, new_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors when data violates float' do
      new_hash = template_hash.deep_dup
      new_hash['validations'] = { 'format' => 'float' }
      validator = subject.new('5.333E-4', new_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'produces no warning when an unsupported keyword is used' do
      new_template = template_hash_val.deep_dup.merge({ 'validations' => { 'maxi' => 3 } })
      validator = subject.new(7.999, new_template)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end
  end
end
