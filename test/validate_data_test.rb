require 'test_helper'

module DataCycleCore
  module MasterData
    class ValidateDataTest < ActiveSupport::TestCase
      test "the truth" do
        assert true
      end

      test "initialize" do
        validate_object = DataCycleCore::MasterData::ValidateData.new
        init_error_hash = { error: [], warning: []}
        assert_equal(validate_object.error, init_error_hash)
      end


    end
  end
end
