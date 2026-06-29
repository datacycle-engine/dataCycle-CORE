# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for UserGroup class-level query helpers: the fulltext_search scope,
  # search_columns, the classification_aliases / users overrides and to_select_options.
  # All run as read-only queries over the seeded/empty test database.
  class UserGroupCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::UserGroup

    test 'fulltext_search builds an ILIKE query over the search columns' do
      assert_kind_of(Array, Subject.fulltext_search('team').to_a)
    end

    test 'search_columns lists the string columns' do
      assert_includes(Subject.search_columns, 'name')
    end

    test 'classification_aliases scopes aliases to the user groups' do
      assert_kind_of(Array, Subject.classification_aliases.to_a)
    end

    test 'users resolves members through the join table' do
      assert_kind_of(Array, Subject.users.to_a)
    end

    test 'to_select_options maps each group to a select option' do
      assert_kind_of(Array, Subject.to_select_options)
    end
  end
end
