# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DefaultValue
      class UserGroupClassificationTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::DefaultValue::UserGroupClassification
        end

        def user_with_classification_ids(ids)
          chain = Class.new {
            define_method(:try) { |_key| self }
            define_method(:primary_classifications) { self }
            define_method(:pluck) { |_attribute| ids }
          }.new

          struct_double(user_groups: chain)
        end

        test 'by_user returns nil without a current user' do
          assert_nil(subject.by_user(current_user: nil, key: 'editors'))
        end

        test 'by_user wraps the primary classification ids of the user group resolved by key' do
          current_user = user_with_classification_ids([10, 20])

          assert_equal([10, 20], subject.by_user(current_user:, key: 'editors'))
        end

        test 'by_user returns nil for an ambiguous value of a single-valued relation' do
          current_user = user_with_classification_ids([10, 20])

          DataCycleCore::Feature::UserGroupClassification.stub(:attribute_relations, { 'editors' => { 'multiple' => false } }) do
            assert_nil(subject.by_user(current_user:, key: 'editors'))
          end
        end

        test 'by_user keeps a single value of a single-valued relation' do
          current_user = user_with_classification_ids([10])

          DataCycleCore::Feature::UserGroupClassification.stub(:attribute_relations, { 'editors' => { 'multiple' => false } }) do
            assert_equal([10], subject.by_user(current_user:, key: 'editors'))
          end
        end
      end
    end
  end
end
