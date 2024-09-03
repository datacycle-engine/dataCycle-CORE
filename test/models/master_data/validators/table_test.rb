# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Table do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Table
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'table',
        'storage_location' => 'value'
      }
    end

    let(:required_template_hash) do
      {
        'label' => 'Test',
        'type' => 'table',
        'storage_location' => 'translated_value',
        'validations' => { 'required' => true }
      }
    end

    let(:soft_required_template_hash) do
      {
        'label' => 'Test',
        'type' => 'table',
        'storage_location' => 'translated_value',
        'validations' => { 'soft_required' => true }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'works with a blank values' do
      validator = subject.new(nil, template_hash)
      assert_equal(no_error_hash, validator.error)

      validator = subject.new([], template_hash)
      assert_equal(no_error_hash, validator.error)

      validator = subject.new([[], []], template_hash)
      assert_equal(no_error_hash, validator.error)
    end

    it 'works with a real values' do
      validator = subject.new([['a', 'b'], [1, 2]], template_hash)
      assert_equal(no_error_hash, validator.error)

      validator = subject.new([['a', 'b']], template_hash)
      assert_equal(no_error_hash, validator.error)

      validator = subject.new([['a', 'b', 'c'], [1, 2, 3], [4, 5, 6]], template_hash)
      assert_equal(no_error_hash, validator.error)
    end

    it 'errors with a wrong column counts' do
      validator = subject.new([['a', 'b'], [2]], template_hash)
      assert_equal(1, validator.error[:error].size)

      validator = subject.new([['a', 'b'], []], template_hash)
      assert_equal(1, validator.error[:error].size)

      validator = subject.new([nil], template_hash)
      assert_equal(1, validator.error[:error].size)
    end

    it 'errors with one error for each wrong column count' do
      validator = subject.new([['a', 'b'], [2], [1, 2, 3], []], template_hash, 'tmp')
      assert_equal(3, validator.error.dig(:error, 'tmp').size)
    end

    it 'errors with a missing required value' do
      validator = subject.new([], required_template_hash)
      assert_equal(1, validator.error[:error].size)

      validator = subject.new([[], []], required_template_hash)
      assert_equal(1, validator.error[:error].size)

      validator = subject.new(nil, required_template_hash)
      assert_equal(1, validator.error[:error].size)
    end

    it 'warns with a missing soft_required value' do
      validator = subject.new([], soft_required_template_hash)
      assert_equal(1, validator.error[:warning].size)

      validator = subject.new([[], []], soft_required_template_hash)
      assert_equal(1, validator.error[:warning].size)

      validator = subject.new(nil, soft_required_template_hash)
      assert_equal(1, validator.error[:warning].size)
    end
  end
end
