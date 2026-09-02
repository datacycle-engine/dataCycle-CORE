# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Abilities
    # #27657: the external URI of a concept is a technical mapping detail (license URLs, foreign ids),
    # so classification tooltips only render it for system_admin. The helper test covers the gate
    # itself - this guards the grant, i.e. that the permission really is exclusive to that role.
    class ConceptUriPermissionTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def ability_for(role_name)
        role = DataCycleCore::Role.find_by(name: role_name)

        assert_not_nil role, "role #{role_name} is missing from the test database"

        DataCycleCore::Ability.new(DataCycleCore::User.new(role:))
      end

      test 'system_admin may show the external uri of a concept' do
        assert ability_for('system_admin').can?(:show_uri, DataCycleCore::ClassificationAlias)
      end

      test 'every other role may not show the external uri of a concept' do
        (DataCycleCore::Role.pluck(:name) - ['system_admin']).each do |role_name|
          assert_not ability_for(role_name).can?(:show_uri, DataCycleCore::ClassificationAlias), "#{role_name} must not see concept uris"
        end
      end
    end
  end
end
