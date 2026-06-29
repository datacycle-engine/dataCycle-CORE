# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the UsersByEmailDomain ability segment - the email-suffix include?
  # predicate and to_restrictions.
  class UsersByEmailDomainSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::UsersByEmailDomain

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

    test 'include? matches users whose email ends with the domain' do
      seg = Subject.new('example.com')

      assert_includes seg, user_double('a@example.com')
      assert_not seg.include?(user_double('a@other.com'))
    end

    test 'subject is User and to_restrictions renders the domain' do
      seg = with_locale_ability(Subject.new('example.com'))

      assert_equal DataCycleCore::User, seg.subject
      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end
