# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Number do
  include DataCycleCore::MinitestSpecHelper

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
      assert_nil(subject.new(10, 10.0001, template_hash).diff_hash)
      assert_nil(subject.new(10, 10.0001).diff_hash)
    end

    it 'recognizes a deleted value' do
      assert_equal(['-', 10], subject.new(10, nil, template_hash).diff_hash)
      assert_equal(['-', 10], subject.new(10, nil).diff_hash)
    end

    it 'recognizes an inserted value' do
      assert_equal(['+', 10], subject.new(nil, 10, template_hash).diff_hash)
      assert_equal(['+', 10], subject.new(nil, 10).diff_hash)
    end

    it 'recognizes integer format' do
      integer_template = template_hash.deep_dup
      integer_template['validations'] = { 'format' => 'integer' }
      [[10, 10.001], ['10', '10.001'], ['10', 10.1], [10.1, 10.3245], [10, 10.999999999]].each do |item|
        assert_nil(subject.new(item[0], item[1], integer_template).diff_hash)
      end
    end

    it 'recognizes float format' do
      integer_template = template_hash.deep_dup
      integer_template['validations'] = { 'format' => 'float' }
      [[10, 10.00101], ['10', '10.00101'], ['10', 10.1], [10.1, 10.3245], [10, 10.999999999]].each do |item|
        assert_equal(['~', item[0].to_f, item[1].to_f], subject.new(item[0], item[1], integer_template).diff_hash)
      end
    end

    it 'recognizes delta epsilon for float format' do
      float_template = template_hash.deep_dup
      float_template['validations'] = { 'format' => 'float' }
      assert_nil(subject.new(10, 10.0001, float_template).diff_hash)
    end
  end
end
