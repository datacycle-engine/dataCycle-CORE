# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Computed do
  subject do
    DataCycleCore::MasterData::Validators::Computed
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'computed',
        'storage_location' => 'value',
        'compute' => {
          'type' => 'string',
          'module' => 'Utility::Compute::Common',
          'method' => 'copy',
          'parameters' => {
            '0' => 'whatEver'
          }
        },
        'validations' => {
          'required' => true
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'works with a string' do
      validator = subject.new('test-string', template_hash)
      assert_equal(no_error_hash, validator.error)
    end

    it 'errors with wrong data' do
      validator = subject.new(10, template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when string is nil and required true' do
      validator = subject.new(nil, template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end
  end
end
