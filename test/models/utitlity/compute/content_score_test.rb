# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class ContentScoreTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::ContentScore
        end

        test 'calculate_from_feature returns the rounded percentage score' do
          content = Class.new {
            def content_score_allowed? = true
            def calculate_content_score(_current_user, _data_hash) = 0.426
          }.new

          assert_equal(43, subject.calculate_from_feature(content:, data_hash: {}))
        end

        test 'calculate_from_feature returns nil when content scoring is not allowed' do
          content = Class.new {
            def content_score_allowed? = false
          }.new

          assert_nil(subject.calculate_from_feature(content:, data_hash: {}))
        end

        test 'calculate_from_feature returns nil when content does not support scoring' do
          assert_nil(subject.calculate_from_feature(content: Object.new, data_hash: {}))
        end
      end
    end
  end
end
