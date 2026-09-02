# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    # Coverage for the cleanup behind dc:sync:cleanup_exports: every check here stands between an
    # operator and a mass delete.
    class StaleCleanupTest < DataCycleCore::TestCases::ActiveSupportTestCase
      SUBJECT = DataCycleCore::Export::StaleCleanup

      before(:all) do
        @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
        @article = create_content('Artikel', { name: 'Stale Cleanup Article' })
        @image = create_content('Bild', { name: 'Stale Cleanup Image' })

        @endpoint = DataCycleCore::StoredFilter.new(name: 'Stale Cleanup Endpoint', user_id: @admin.id)
          .parameters_from_hash([{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Artikel'] } }])
        @endpoint.save!

        @external_system = DataCycleCore::ExternalSystem.create!(
          name: 'Stale Cleanup ES',
          config: {
            'export_config' => {
              'endpoint' => 'DataCycleCore::Export::Generic::Endpoint',
              'filter' => { 'endpoints' => [@endpoint.id] },
              'delete' => { 'strategy' => 'DataCycleCore::Export::Generic::Delete' }
            }
          }
        )

        [@article, @image].each do |thing|
          DataCycleCore::ExternalSystemSync.create!(syncable: thing, external_system: @external_system, external_key: thing.id, sync_type: 'export')
        end
      end

      def cleanup(external_system: @external_system, **)
        SUBJECT.new(external_system:, **)
      end

      # the contents a delete was pushed for
      def pushed(**, &)
        ids = []

        DataCycleCore::Export::Generic::Delete.stub(:process, ->(data:, **) { ids << data.id }) do
          cleanup(**).call(&)
        end

        ids
      end

      test 'only the exported contents no endpoint contains are stale' do
        assert_equal [@image.id], cleanup.stale.ids
      end

      test 'a template_names restriction narrows the exported set it compares' do
        assert_empty cleanup(template_names: ['Artikel']).stale.ids
      end

      # the whole point of the argument: retire one template from an export the endpoints still
      # legitimately contain nothing of
      test 'a template_names restriction may match only stale contents' do
        assert_equal [@image.id], cleanup(template_names: ['Bild']).stale.ids
      end

      test 'an export that never reached the receiver is not stale' do
        failed = create_content('Bild', { name: 'Stale Cleanup Failed Image' })
        DataCycleCore::ExternalSystemSync.create!(syncable: failed, external_system: @external_system, external_key: failed.id, sync_type: 'export', status: 'failure')

        assert_equal [@image.id], cleanup.stale.ids
      end

      test 'a dry run yields every stale content and pushes nothing' do
        yielded = []

        ids = pushed { |thing| yielded << thing.id }

        assert_empty ids
        assert_equal [@image.id], yielded
      end

      test 'execute pushes a delete for every stale content' do
        DataCycleCore.stub(:webhooks, [@external_system.name]) do
          assert_equal [@image.id], pushed(execute: true)
        end
      end

      test 'it raises rather than deleting the entire export when no endpoint contains anything' do
        parameters = @endpoint.parameters

        @endpoint.update!(parameters: [{ 'n' => 'Inhaltstypen', 't' => 'classification_alias_ids', 'v' => [SecureRandom.uuid] }])

        assert_raises(SUBJECT::Error) { cleanup.stale }
      ensure
        @endpoint.update!(parameters:)
      end

      test 'it names the configured endpoints that do not exist' do
        config = @external_system.config
        missing = SecureRandom.uuid

        @external_system.update!(config: config.deep_merge('export_config' => { 'filter' => { 'endpoints' => [@endpoint.id, missing] } }))
        @external_system.reload

        error = assert_raises(SUBJECT::Error) { cleanup.stale }

        assert_includes error.message, missing
      ensure
        @external_system.update!(config:)
        @external_system.reload
      end

      # the filter section is keyed by the update strategy's own name, not by 'update', and reading
      # the wrong one means deleting whatever the right one contains
      test 'it reads the endpoints the update strategy is filtered by' do
        config = @external_system.config
        bild_endpoint = DataCycleCore::StoredFilter.new(name: 'Stale Cleanup Bild Endpoint', user_id: @admin.id)
          .parameters_from_hash([{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Bild'] } }])
        bild_endpoint.save!

        export_config = {
          'update' => { 'strategy' => 'DataCycleCore::Export::Onlim::PushUpdate' },
          'push_update' => { 'filter' => { 'endpoints' => [bild_endpoint.id] } }
        }

        # ExternalSystem memoizes export_config, and update! alone leaves the memo stale
        @external_system.update!(config: config.deep_merge('export_config' => export_config))
        @external_system.reload

        assert_equal [@article.id], cleanup.stale.ids
      ensure
        @external_system.update!(config:)
        @external_system.reload
      end

      test 'it raises on execute for a system the host may not send webhooks to' do
        DataCycleCore.stub(:webhooks, ['Some Other System']) do
          assert_raises(SUBJECT::Error) { cleanup(execute: true).stale }
        end
      end

      test 'it raises for a system without an export_config' do
        system = DataCycleCore::ExternalSystem.create!(name: 'Stale Cleanup No Config ES')

        assert_raises(SUBJECT::Error) { cleanup(external_system: system).stale }
      end
    end
  end
end
