# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the small ability-segment classes that were left below 90%:
  # the StoredFilter shared/api-shared subjects, and the data-link / api-token /
  # provider / user-group-users predicate variants. All are exercised over plain
  # doubles (no DB) via the standard `ability.user` wiring.
  class UnderNinetySegmentsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    S = DataCycleCore::Abilities::Segments

    # a double whose (possibly `?`-suffixed, possibly arg-taking) methods return fixed values
    def user_double(**methods)
      obj = Object.new
      methods.each { |name, val| obj.define_singleton_method(name) { |*| val } }
      obj
    end

    def with_ability(seg, user = nil)
      ability = Object.new
      ability.define_singleton_method(:user) { user }
      seg.ability = ability
      seg
    end

    test 'StoredFilter shared/api-shared subjects instantiate with the StoredFilter subject' do
      [
        S::StoredFilterBySharedRoles, S::StoredFilterBySharedUserGroups, S::StoredFilterBySharedUsers,
        S::StoredFilterByApiAndSharedRoles, S::StoredFilterByApiAndSharedUserGroups, S::StoredFilterByApiAndSharedUsers
      ].each do |klass|
        assert_equal DataCycleCore::StoredFilter, klass.new.instance_variable_get(:@subject)
      end
    end

    test 'StoredFilterByCreatorAndApi builds creator + api conditions' do
      seg = with_ability(S::StoredFilterByCreatorAndApi.new, user_double(id: 42))

      assert_equal DataCycleCore::StoredFilter, seg.subject
      assert_equal({ user_id: 42, api: true }, seg.conditions)
    end

    test 'SubjectByUserAndUserGroupUsers conditions, to_s and to_restrictions' do
      seg = with_ability(
        S::SubjectByUserAndUserGroupUsers.new(DataCycleCore::User, 'creator_id'),
        user_double(include_groups_user_ids: [1, 2], ui_locale: :de)
      )

      assert_equal({ creator_id: [1, 2] }, seg.conditions)
      assert_nothing_raised { seg.to_s }
      assert_nothing_raised { seg.send(:to_restrictions, subject: DataCycleCore::User) }
    end

    test 'BackendByReadableDataLinks#valid_data_links? reads the user readable data links' do
      seg = with_ability(S::BackendByReadableDataLinks.new, user_double(valid_received_readable_data_links: []))

      assert_not seg.include?
    end

    test 'UsersByUserGroupAndApiToken requires role, group and an access token' do
      seg = with_ability(S::UsersByUserGroupAndApiToken.new('TestUserGroup', ['admin']))
      user = user_double(is_role?: true, has_user_group?: true, access_token: 'tok')

      assert_includes seg, user
      assert_not seg.include?(user_double(is_role?: true, has_user_group?: true, access_token: nil))
    end

    test 'UsersByRoleAndProvider requires the role and a provider uid' do
      seg = with_ability(S::UsersByRoleAndProvider.new('admin', 'pixelpoint_aad_v2'))

      assert_includes seg, user_double(is_role?: true, pixelpoint_aad_v2_uid: 'uid-1')
      assert_not seg.include?(user_double(is_role?: true, pixelpoint_aad_v2_uid: nil))
      assert_nothing_raised { seg.send(:to_restrictions) }
    end

    test 'StoredFilterByDataLink include? gates on data links and filter type' do
      no_links = with_ability(S::StoredFilterByDataLink.new(['export']), user_double(valid_received_readable_stored_filter_data_links: []))

      assert_not no_links.include?

      with_links = with_ability(S::StoredFilterByDataLink.new(['export']), user_double(valid_received_readable_stored_filter_data_links: [1]))

      # multi-arg include? (the segment predicate, not a collection) — assert_includes would
      # drop the trailing args and change what is tested, so keep the plain assert.
      assert with_links.include?(nil, nil, nil) # rubocop:disable Minitest/AssertIncludes
      assert with_links.include?(nil, nil, 'export') # rubocop:disable Minitest/AssertIncludes
      assert_not with_links.include?(nil, nil, 'other')
      assert_respond_to with_links.to_proc, :call
    end
  end
end
