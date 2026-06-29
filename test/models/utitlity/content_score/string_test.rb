# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class StringTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::ContentScore::String
        end

        test 'by_length scores the sanitized character count against the score matrix' do
          definition = { 'content_score' => { 'score_matrix' => { 'min' => 3, 'max' => 10 } } }

          assert_equal(1, subject.by_length(definition:, data_hash: { 'description' => '<b>hello</b>' }, key: 'description'))
        end

        test 'by_length scores 0 for content shorter than the minimum' do
          definition = { 'content_score' => { 'score_matrix' => { 'min' => 10, 'max' => 20 } } }

          assert_equal(0, subject.by_length(definition:, data_hash: { 'description' => 'short' }, key: 'description'))
        end
      end
    end
  end
end
