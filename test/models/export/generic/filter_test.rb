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
          @data = create_content('Artikel', { name: 'Export Filter Article', tags: get_classification_ids('Tags', 'Tag 3') })
          @other = create_content('Bild', { name: 'Export Filter Image' })

          @endpoint = DataCycleCore::StoredFilter.new(name: 'Export Endpoint', user_id: @admin.id)
            .parameters_from_hash([{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Artikel'] } }])
          @endpoint.save!

          @bild_endpoint = DataCycleCore::StoredFilter.new(name: 'Bild Endpoint', user_id: @admin.id, linked_stored_filter_id: @endpoint.id)
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

        test 'filter_endpoints returns false when data is absent and has no dependents' do
          assert_not SUBJECT.filter_endpoints(**args('bildfilter'))
        end

        test 'filter_endpoints checks depending contents against the endpoint' do
          @data.stub(:depending_contents, DataCycleCore::Thing.where(id: @other.id)) do
            assert SUBJECT.filter_endpoints(**args('bildfilter'))
          end
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
