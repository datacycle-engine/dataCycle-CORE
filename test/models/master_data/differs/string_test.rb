# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::String do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::String
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'string',
        'storage_location' => 'column'
      }
    end

    it 'recognizes equal strings' do
      assert_nil(subject.new('test', 'test').diff_hash)
    end

    it 'recognizes equivalent unicode strings' do
      a = "Henry\u2163"
      b = 'HenryIV'
      assert_equal('~', subject.new(a, b).diff_hash[0])
    end
  end
end
