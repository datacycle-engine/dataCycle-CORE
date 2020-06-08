# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::Computed do
  subject do
    DataCycleCore::MasterData::Differs::Computed
  end

  describe 'diff data' do
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
        }
      }
    end

    it 'recognizes equal strings' do
      assert_nil(subject.new('test', 'test', template_hash).diff_hash)
    end

    it 'recognizes equivalent unicode strings' do
      a = "Henry\u2163"
      b = 'HenryIV'

      assert_equal('~', subject.new(a, b, template_hash).diff_hash[0])
    end

    it 'recognizes non equal strings' do
      assert_equal(['~', 'test', 'test123'], subject.new('test', 'test123', template_hash).diff_hash)
    end
  end
end
