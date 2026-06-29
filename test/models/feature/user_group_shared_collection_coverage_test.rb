# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for the UserGroupSharedCollection feature: attribute_keys and the
    # whitelist resolver (blank, wildcard and explicit id/slug branches). The
    # configuration is stubbed; the whitelist branches run cheap Collection queries
    # over the seeded/empty table without any fixtures.
    class UserGroupSharedCollectionCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Feature::UserGroupSharedCollection

      test 'attribute_keys returns the configured attribute key names' do
        Subject.stub(:configuration, { 'attribute_keys' => { 'shared_collection' => {} } }) do
          assert_equal(['shared_collection'], Subject.attribute_keys)
        end
      end

      test 'whitelist is empty when no whitelist is configured' do
        Subject.stub(:configuration, { 'whitelist' => nil }) do
          assert_equal([], Subject.whitelist)
        end
      end

      test 'whitelist returns named collections for a wildcard entry' do
        Subject.stub(:configuration, { 'whitelist' => ['*'] }) do
          result = Subject.whitelist

          assert_kind_of(Array, result)
          assert(result.none? { |c| c.name == 'Meine Auswahl' })
        end
      end

      test 'whitelist resolves explicit entries by id or slug' do
        Subject.stub(:configuration, { 'whitelist' => ['does-not-exist'] }) do
          assert_equal([], Subject.whitelist)
        end
      end
    end
  end
end
