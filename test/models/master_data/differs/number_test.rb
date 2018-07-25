# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::Number do
  subject do
    DataCycleCore::MasterData::Differs::Number
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'number',
        'storage_location' => 'translated_value'
      }
    end

    it 'properly diffs integer' do
      assert_nil(subject.new(10, 10, template_hash).diff_hash)
      assert_nil(subject.new(10, 10).diff_hash)
    end

    it 'properly diffs integer with floats' do
      assert_nil(subject.new(10, 10.0, template_hash).diff_hash)
      assert_nil(subject.new(10, 10.0).diff_hash)
    end

    it 'properly diffs float within epsilon of 1e-6' do
      assert_nil(subject.new(10, 10.0000001, template_hash).diff_hash)
      assert_nil(subject.new(10, 10.0000001).diff_hash)
    end

    it 'recognizes a deleted value' do
      assert_equal(['-', 10], subject.new(10, nil, template_hash).diff_hash)
      assert_equal(['-', 10], subject.new(10, nil).diff_hash)
    end

    it 'recognizes an inserted value' do
      assert_equal(['+', 10], subject.new(nil, 10, template_hash).diff_hash)
      assert_equal(['+', 10], subject.new(nil, 10).diff_hash)
    end

    it 'recognizes float format' do
      float_template = template_hash.deep_dup
      float_template['validations'] = { 'format' => 'float' }
      assert_nil(subject.new(10, 10.000000000001, float_template).diff_hash)
    end

    it 'recognizes integer format' do
      integer_template = template_hash.deep_dup
      integer_template['validations'] = { 'format' => 'integer' }
      assert_equal(['~', 10, 10.000000000001], subject.new(10, 10.000000000001, integer_template).diff_hash)
    end
  end
end
