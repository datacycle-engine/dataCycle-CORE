# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    module Generic
      # Coverage for the export webhook filters (Export::Generic::Filter).
      class FilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
        SUBJECT = DataCycleCore::Export::Generic::Filter

        before(:all) do
          @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
          @other = create_content('Bild', { name: 'Export Filter Image' })
          @data = create_content('Artikel', { name: 'Export Filter Article', tags: get_classification_ids('Tags', 'Tag 3'), image: [@other.id] })

          @endpoint = DataCycleCore::StoredFilter.new(name: 'Export Endpoint', user_id: @admin.id)
            .parameters_from_hash([{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Artikel'] } }])
          @endpoint.save!

          @bild_endpoint = DataCycleCore::StoredFilter.new(name: 'Bild Endpoint', user_id: @admin.id)
            .parameters_from_hash([{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Bild'] } }])
          @bild_endpoint.save!

          @watch_list = DataCycleCore::WatchList.create!(full_path: 'Export Filter WL', user: @admin)
          @watch_list.things << @data

          @external_system = DataCycleCore::ExternalSystem.create!(
            name: 'Export Filter ES',
            config: {
              'export_config' => {
                'covfilter' => { 'filter' => {
                  'presence' => ['name'],
                  'template_names' => ['Artikel'],
                  'classifications' => [{ 'tree_label' => 'Tags', 'aliases' => ['Tag 3'] }],
                  'tree_labels' => ['Tags'],
                  'watch_lists' => [@watch_list.id],
                  'stored_filters' => [@endpoint.id],
                  'endpoints' => [@endpoint.id]
                } },
                'bildfilter' => { 'filter' => { 'endpoints' => [@bild_endpoint.id] } }
              }
            }
          )
        end

        def args(method_name = 'covfilter')
          { data: @data, external_system: @external_system, method_name: }
        end

        test 'filter_presence verifies configured presence attributes' do
          assert SUBJECT.filter_presence(**args)
        end

        test 'filter_template_names matches the configured template names' do
          assert SUBJECT.filter_template_names(**args)
        end

        test 'filter_external_system_names passes when unconfigured' do
          assert SUBJECT.filter_external_system_names(**args)
        end

        test 'filter_classifications matches the configured classifications' do
          assert SUBJECT.filter_classifications(**args)
        end

        test 'filter_tree_labels matches the configured tree labels' do
          assert SUBJECT.filter_tree_labels(**args)
        end

        test 'filter_watch_lists checks the configured watch lists' do
          assert SUBJECT.filter_watch_lists(**args)
        end

        test 'filter_stored_filters checks the configured stored filters' do
          assert SUBJECT.filter_stored_filters(**args)
        end

        test 'filter_endpoints matches data contained in a configured endpoint' do
          assert SUBJECT.filter_endpoints(**args)
        end

        test 'filter_endpoints returns false when no configured endpoint contains the data' do
          assert_not SUBJECT.filter_endpoints(**args('bildfilter'))
        end

        test 'filter_endpoints rejects a content the endpoint only links' do
          assert_equal [@data.id], @other.depending_contents.pluck(:id)
          assert_not SUBJECT.filter_endpoints(data: @other, external_system: @external_system, method_name: 'covfilter')
        end

        test 'endpoints_for returns nil when no endpoints are configured' do
          assert_nil SUBJECT.endpoints_for(@external_system, 'unconfigured')
        end

        # what DataCycleCore::Export::StaleCleanup reports its guards on, and the reason it reads the
        # ids through here rather than off the config a second time
        test 'endpoint_ids_for returns the configured ids' do
          assert_equal [@endpoint.id], SUBJECT.endpoint_ids_for(@external_system, 'covfilter')
          assert_empty SUBJECT.endpoint_ids_for(@external_system, 'unconfigured')
        end

        # A filter is keyed by the strategy's name, not by the action, and the two sides derive that
        # key separately: the export through export_filter_method_name off the config string, the
        # strategy off its own class name. The action here is deliberately not the strategy's name,
        # or the two would agree by coincidence.
        test 'the configured filter key is the one the strategy itself reads' do
          named = DataCycleCore::ExternalSystem.new(config: { 'export_config' => { 'delete' => { 'strategy' => 'DataCycleCore::Export::Generic::Update' } } })
          passed = nil
          stub = ->(**kwargs) { passed = kwargs[:method_name] }

          DataCycleCore::Export::Generic::Functions.stub(:filter, stub) do
            DataCycleCore::Export::Generic::Update.filter(@data, named)
          end

          assert_equal 'update', passed
          assert_equal passed, named.export_filter_method_name(:delete)

          # no strategy configured is the generic one PushObject#webhook builds, named after nothing
          generic = DataCycleCore::ExternalSystem.new(config: { 'export_config' => {} })

          DataCycleCore::Export::Generic::Filter.stub(:filter, stub) do
            DataCycleCore::Export::Generic::Base.new(action: :delete).filter(@data, generic)
          end

          assert_equal 'delete', passed
          assert_equal passed, generic.export_filter_method_name(:delete)
        end

        test 'a delete goes by what was exported, whatever the configured filter' do
          assert_not SUBJECT.filter(data: @data, external_system: @external_system, method_name: 'delete')
          assert_not SUBJECT.filter(data: @data, external_system: @external_system, method_name: 'force_delete')

          DataCycleCore::ExternalSystemSync.create!(syncable: @data, external_system: @external_system, external_key: @data.id, sync_type: 'export')

          assert SUBJECT.filter(data: @data.reload, external_system: @external_system, method_name: 'delete')
          assert SUBJECT.filter(data: @data, external_system: @external_system, method_name: 'force_delete')
        end

        # the sync row is written before the request goes out, so its existence alone would send a
        # delete for an id the receiver has never seen
        test 'a delete is not sent for an export that never reached the receiver' do
          sync = DataCycleCore::ExternalSystemSync.create!(syncable: @other, external_system: @external_system, external_key: @other.id, sync_type: 'export', status: 'failure')

          assert_not SUBJECT.filter(data: @other.reload, external_system: @external_system, method_name: 'delete')

          sync.update!(last_successful_sync_at: 1.day.ago)

          assert SUBJECT.filter(data: @other.reload, external_system: @external_system, method_name: 'delete')
        ensure
          sync&.destroy
        end

        test 'filter dispatches to filter_endpoints when endpoints are configured' do
          assert SUBJECT.filter(**args)
        end

        test 'filter runs all webhook filters when no endpoints are configured' do
          assert SUBJECT.filter(**args('unconfigured'))
        end
      end
    end
  end
end
