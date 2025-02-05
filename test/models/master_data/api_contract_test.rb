# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ApiContractTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @validator = DataCycleCore::MasterData::Contracts::ApiContract.new
    end

    test 'filter[classifications][in][withSubtree][] returns error for invalid params' do
      validation = @validator.call({ filter: { classifications: { in: { withSubtree: [0] } } } })

      assert_equal 1, validation.errors.count
      assert_equal [:filter, :classifications, :in, :withSubtree, 0], validation.errors.to_a.first.path
      assert_equal 'must be a valid UUID or a list of UUIDs separated by commas', validation.errors.to_a.first.to_s

      validation = @validator.call({ filter: { classifications: { in: { withoutSubtree: ['0'] } } } })

      assert_equal 1, validation.errors.count
      assert_equal [:filter, :classifications, :in, :withoutSubtree, 0], validation.errors.to_a.first.path
      assert_equal 'must be a valid UUID or a list of UUIDs separated by commas', validation.errors.to_a.first.to_s

      validation = @validator.call({ filter: { classifications: { in: { withoutSubtree: [' '] } } } })

      assert_equal 1, validation.errors.count
      assert_equal [:filter, :classifications, :in, :withoutSubtree, 0], validation.errors.to_a.first.path
      assert_equal 'must be a valid UUID or a list of UUIDs separated by commas', validation.errors.to_a.first.to_s

      validation = @validator.call({ filter: { classifications: { notIn: { withSubtree: ['b6d30f72-8a3d-47ee-b21b-860ed6fae232', '0'] } } } })

      assert_equal 1, validation.errors.count
      assert_equal [:filter, :classifications, :notIn, :withSubtree, 1], validation.errors.to_a.first.path
      assert_equal 'must be a valid UUID or a list of UUIDs separated by commas', validation.errors.to_a.first.to_s

      validation = @validator.call({ filter: { classifications: { in: { withSubtree: ['234234 ,   b6d30f72-8a3d-47ee-b21b-860ed6fae232', '0'] } } } })

      assert_equal 2, validation.errors.count
      assert_equal [:filter, :classifications, :in, :withSubtree, 0], validation.errors.to_a.first.path
      assert_equal 'must be a valid UUID or a list of UUIDs separated by commas', validation.errors.to_a.first.to_s
      assert_equal [:filter, :classifications, :in, :withSubtree, 1], validation.errors.to_a.last.path
      assert_equal 'must be a valid UUID or a list of UUIDs separated by commas', validation.errors.to_a.last.to_s
    end

    test 'filter[classifications][in][withSubtree][] works with valid params' do
      validation = @validator.call({ filter: { classifications: { in: { withSubtree: ['b6d30f72-8a3d-47ee-b21b-860ed6fae232'] } } } })

      assert_empty validation.errors

      validation = @validator.call({ filter: { classifications: { in: { withSubtree: ['b6d30f72-8a3d-47ee-b21b-860ed6fae232', 'b6d30f72-8a3d-47ee-b21b-860ed6fae232', 'b6d30f72-8a3d-47ee-b21b-860ed6fae232'] } } } })

      assert_empty validation.errors

      validation = @validator.call({ filter: { classifications: { in: { withSubtree: ['b6d30f72-8a3d-47ee-b21b-860ed6fae232,b6d30f72-8a3d-47ee-b21b-860ed6fae232,b6d30f72-8a3d-47ee-b21b-860ed6fae232', 'b6d30f72-8a3d-47ee-b21b-860ed6fae232,b6d30f72-8a3d-47ee-b21b-860ed6fae232,b6d30f72-8a3d-47ee-b21b-860ed6fae232', 'b6d30f72-8a3d-47ee-b21b-860ed6fae232,b6d30f72-8a3d-47ee-b21b-860ed6fae232'] } } } })

      assert_empty validation.errors

      validation = @validator.call({ filter: { classifications: { in: { withSubtree: ['  b6d30f72-8a3d-47ee-b21b-860ed6fae232   ', '   b6d30f72-8a3d-47ee-b21b-860ed6fae232    ', 'b6d30f72-8a3d-47ee-b21b-860ed6fae232'] } } } })

      assert_empty validation.errors

      validation = @validator.call({ filter: { classifications: { in: { withSubtree: ['  b6d30f72-8a3d-47ee-b21b-860ed6fae232  , b6d30f72-8a3d-47ee-b21b-860ed6fae232 ,    b6d30f72-8a3d-47ee-b21b-860ed6fae232,b6d30f72-8a3d-47ee-b21b-860ed6fae232', '   b6d30f72-8a3d-47ee-b21b-860ed6fae232 ,b6d30f72-8a3d-47ee-b21b-860ed6fae232   ', 'b6d30f72-8a3d-47ee-b21b-860ed6fae232'] } } } })

      assert_empty validation.errors

      validation = @validator.call({ filter: { classifications: { in: { withSubtree: [''] } } } })

      assert_empty validation.errors
    end
  end
end
