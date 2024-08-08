# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Table do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::Table
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'table',
        'storage_location' => 'value'
      }
    end

    it 'recognizes equal tables' do
      assert_nil(subject.new([['a', 'b'], [1, 2]], [['a', 'b'], [1, 2]]).diff_hash)
    end

    it 'recognizes different tables' do
      assert_equal('~', subject.new([['a', 'b'], [1, 2]], [['a', 'b'], [1, 3]]).diff_hash[0])
    end
  end
end
