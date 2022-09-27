# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Base
        class ScoreByQuantity < DataCycleCore::TestCases::ActiveSupportTestCase
          test 'score_by_quantity returns 0 without score_matrix' do
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(5, nil)
          end

          test 'score_by_quantity returns 0 when quantity is not a number' do
            config = { 'min' => 1 }.freeze
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity('test', config)
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(nil, config)
          end

          test 'score_by_quantity works with only min' do
            config = { 'min' => 1 }.freeze
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(0, config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(1, config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(2.0, config)
          end

          test 'score_by_quantity works with min and optimal' do
            config = { 'min' => 1, 'optimal' => 2 }.freeze
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(0, config)
            assert_equal 0.01, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(1, config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(2.0, config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(3, config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(4, config)
          end

          test 'score_by_quantity works with min, optimal and max' do
            config = { 'min' => 1, 'optimal' => 2, 'max' => 3 }.freeze
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(0, config)
            assert_equal 0.01, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(1, config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(2.0, config)
            assert_equal 0.01, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(3, config)
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(4, config)
          end

          test 'score_by_quantity works with float numbers' do
            config = { 'min' => 1, 'optimal' => 1.5, 'max' => 2 }.freeze
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(0, config)
            assert_equal 0.01, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(1, config)
            assert_equal 0.01, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(2.0, config)
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(3, config)
          end

          test 'score_by_quantity works with rational numbers' do
            config = { 'min' => '4/3', 'max' => '4.5/3' }.freeze
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(Rational(3.5, 3), config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(Rational(4, 3), config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(Rational(4.5, 3), config)
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(Rational(5, 3), config)
          end

          test 'score_by_quantity works with large values' do
            config = { 'min' => 1000, 'optimal' => 1500, 'max' => 2000 }.freeze
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(999, config)
            assert_equal 0.01, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(1000, config)
            assert_equal 0.505, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(1250, config)
            assert_equal 1, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(1500, config)
            assert_equal 0.01, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(2000, config)
            assert_equal 0, DataCycleCore::Utility::ContentScore::Base.score_by_quantity(2001, config)
          end
        end
      end
    end
  end
end
