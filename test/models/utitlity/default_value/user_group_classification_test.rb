# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DefaultValue
      class UserGroupClassificationTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::DefaultValue::UserGroupClassification
        end

        test 'by_user returns nil without a current user' do
          assert_nil(subject.by_user(current_user: nil, key: 'editors'))
        end

        test 'by_user wraps the primary classification ids of the user group resolved by key' do
          chain = Class.new {
            def try(_key) = self
            def primary_classifications = self
            def pluck(_attribute) = [10, 20]
          }.new
          current_user = struct_double(user_groups: chain)

          assert_equal([10, 20], subject.by_user(current_user:, key: 'editors'))
        end
      end
    end
  end
end
