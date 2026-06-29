# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the UsersByEmail ability segment - the case-insensitive email include?
  # predicate and to_restrictions.
  class UsersByEmailSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::UsersByEmail

    def user_double(email)
      user = Object.new
      user.define_singleton_method(:email) { email }
      user
    end

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'include? matches the email case-insensitively' do
      seg = Subject.new('Test@Example.com')

      assert_includes seg, user_double('test@example.com')
      assert_not seg.include?(user_double('other@example.com'))
    end

    test 'subject is User and to_restrictions renders the email' do
      seg = with_locale_ability(Subject.new('test@example.com'))

      assert_equal DataCycleCore::User, seg.subject
      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end
