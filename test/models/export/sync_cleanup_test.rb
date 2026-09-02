# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    class SyncCleanupTest < ActiveSupport::TestCase
      def setup
        @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')

        I18n.with_locale(:de) do
          @organization = DataCycleCore::TestPreparations.create_content(
            template_name: 'Organization',
            data_hash: { name: 'Org 1' },
            prevent_history: true
          )
          # @person links to @organization (member_of) -> organization is a linked child of person
          @person = DataCycleCore::TestPreparations.create_content(
            template_name: 'Person',
            data_hash: { given_name: 'Test', family_name: 'Person 1', member_of: [@organization.id] },
            prevent_history: true
          )
        end
      end

      def create_export_sync(content)
        content.external_system_syncs.create!(external_system: @external_system, sync_type: 'export', status: 'success', external_key: content.id)
      end

      def system_syncs(content)
        content.reload.external_system_syncs.where(external_system_id: @external_system.id)
      end

      test 'removes the content and its orphaned child syncs and writes a history entry for each' do
        create_export_sync(@person)
        create_export_sync(@organization)

        assert_difference(-> { DataCycleCore::Thing::History.count }, 2) do
          DataCycleCore::Export::SyncCleanup.new(content: @person, external_system: @external_system).call
        end

        assert_equal 0, system_syncs(@person).count
        assert_equal 0, system_syncs(@organization).count
      end

      test 'keeps a child sync that another still-exported content references' do
        person2 = I18n.with_locale(:de) do
          DataCycleCore::TestPreparations.create_content(
            template_name: 'Person',
            data_hash: { given_name: 'Test', family_name: 'Person 2', member_of: [@organization.id] },
            prevent_history: true
          )
        end
        create_export_sync(@person)
        create_export_sync(person2)
        create_export_sync(@organization)

        DataCycleCore::Export::SyncCleanup.new(content: @person, external_system: @external_system).call

        assert_equal 0, system_syncs(@person).count
        assert_equal 1, system_syncs(@organization).count, 'child still referenced by exported person2 must be kept'
        assert_equal 1, system_syncs(person2).count
      end

      test 'include_self false keeps the content own sync but removes the orphaned child sync' do
        create_export_sync(@person)
        create_export_sync(@organization)

        DataCycleCore::Export::SyncCleanup.new(content: @person, external_system: @external_system, include_self: false).call

        assert_equal 1, system_syncs(@person).count
        assert_equal 0, system_syncs(@organization).count
      end

      test 'does not remove duplicate syncs of linked children' do
        create_export_sync(@person)
        @organization.external_system_syncs.create!(external_system: @external_system, sync_type: 'duplicate', status: 'success', external_key: @organization.id)

        DataCycleCore::Export::SyncCleanup.new(content: @person, external_system: @external_system).call

        assert_equal 0, system_syncs(@person).count
        assert_equal 1, system_syncs(@organization).count, 'only export syncs of children are removed'
      end
    end
  end
end
