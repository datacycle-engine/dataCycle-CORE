require 'test_helper'

module DataCycleCore
  module MasterData
    class ValidateDataTest < ActiveSupport::TestCase
      test 'the truth' do
        assert true
      end

      test 'initialize' do
        validate_object = DataCycleCore::MasterData::ValidateData.new
        init_error_hash = { error: [], warning: [] }
        assert_equal(init_error_hash, validate_object.error)
      end
    end
  end
end
