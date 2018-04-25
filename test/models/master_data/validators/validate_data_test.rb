require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::ValidateData do
  subject do
    DataCycleCore::MasterData::ValidateData.new
  end

  describe 'validate data' do
    let(:init_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly initializes' do
      assert_equal(init_error_hash, subject.error)
    end
  end
end
