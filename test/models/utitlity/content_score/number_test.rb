# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class NumberTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::ContentScore::Number
        end

        test 'by_quantity scores the numeric value against the score matrix' do
          definition = { 'content_score' => { 'score_matrix' => { 'min' => 1, 'max' => 10 } } }

          assert_equal(1, subject.by_quantity(definition:, data_hash: { 'count' => 5 }, key: 'count'))
        end

        test 'by_presence scores 1 for a positive value and 0 otherwise' do
          assert_equal(1, subject.by_presence(parameters: { 'count' => 5 }, key: 'count'))
          assert_equal(0, subject.by_presence(parameters: { 'count' => 0 }, key: 'count'))
        end

        test 'to_tooltip renders the score matrix as html via the score-matrix extension' do
          definition = { 'content_score' => { 'method' => 'by_quantity', 'score_matrix' => { 'min' => 1, 'max' => 5 } } }

          tooltip = subject.to_tooltip(nil, definition, :de)

          assert_includes(tooltip, '<ul>')
        end

        test 'to_tooltip delegates to the base tooltip without a score matrix' do
          assert_nothing_raised do
            subject.to_tooltip(nil, { 'content_score' => { 'method' => 'by_presence' } }, :de)
          end
        end
      end
    end
  end
end
