# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationFacetsTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            @aliases = @tree_label.classification_aliases.order(internal_name: :asc)
            @current_user = User.find_by(email: 'tester@datacycle.at')
            @current_user.update(access_token: SecureRandom.hex)
            @endpoint = DataCycleCore::StoredFilter.create(api: true, user: @current_user)
            @contents = []
            @count_mapping = {}
            @mapped_classification = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test Mapping').classifications.first
            @aliases.limit(@aliases.size - 1).each do |ca|
              c = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: ca.id, tags: [ca.primary_classification.id], universal_classifications: [@mapped_classification.id] })
              @contents.push(c)
              @count_mapping[ca.id] ||= []
              @count_mapping[ca.id].push(c.id)

              ca.classification_alias_path.ancestor_classification_aliases.each do |aca|
                @count_mapping[aca.id] ||= []
                @count_mapping[aca.id].push(c.id)
              end
            end

            @tag1 = @aliases.find_by(internal_name: 'Tag 1')
            @tag2 = @aliases.find_by(internal_name: 'Tag 2')

            @count_mapping[@aliases.last.id] = []

            perform_enqueued_jobs
          end

          test 'api/v4/endpoints/:endpoint/facets' do
            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              page: {
                size: 100
              }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body
            json_data['@graph'].each do |item|
              assert_equal(@count_mapping[item['@id']].size, item['dc:thingCountWithSubtree'])
              assert_equal(item['dc:thingCountWithSubtree'].positive? ? 1 : 0, item['dc:thingCountWithoutSubtree'])
            end
          end

          test 'api/v4/endpoints/:endpoint/facets with fulltext search' do
            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              filter: {
                search: @tag2.id
              },
              page: {
                size: 100
              }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            assert_equal(@aliases.pluck(:id), json_data['@graph'].pluck('@id'))
            json_data['@graph'].each do |item|
              assert_equal(item['@id'] == @tag2.id ? 1 : 0, item['dc:thingCountWithSubtree'])
            end
          end

          test 'api/v4/endpoints/:endpoint/facets with fulltext search and fields' do
            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              filter: {
                search: {
                  value: @tag2.id,
                  fields: 'name,dc:classification'
                }
              },
              page: {
                size: 100
              }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            assert_equal(@aliases.pluck(:id), json_data['@graph'].pluck('@id'))
            json_data['@graph'].each do |item|
              assert_equal(item['@id'] == @tag2.id ? 1 : 0, item['dc:thingCountWithSubtree'])
            end
          end

          test 'api/v4/endpoints/:endpoint/facets sort dc:thingCountWithSubtree DESC' do
            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              page: {
                size: 100
              },
              sort: '-dc:thingCountWithSubtree'
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            assert_equal(@count_mapping.sort_by { |k, v| [-v.size, k] }.to_h.keys, json_data['@graph'].pluck('@id'))
          end

          test 'api/v4/endpoints/:endpoint/facets with mappings' do
            @tag1.classification_ids += [@mapped_classification.id]
            tmp_mapping = @count_mapping.deep_dup
            tmp_mapping[@tag1.id] = @contents.pluck(:id)

            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              page: {
                size: 100
              }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            json_data['@graph'].each do |item|
              assert_equal(tmp_mapping[item['@id']].size, item['dc:thingCountWithSubtree'])
            end
          end

          test 'api/v4/endpoints/:endpoint/facets with language for things and conceptLanguage for concepts' do
            I18n.with_locale(:en) do
              @tag2.update(name: 'Tag 2 - EN')
            end

            translated_thing = DataCycleCore::Thing.find(@count_mapping[@tag2.id].first)
            I18n.with_locale(:en) do
              translated_thing.set_data_hash(data_hash: { name: "#{translated_thing.name} - EN" })
            end

            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              language: 'en',
              conceptLanguage: 'de',
              fields: 'skos:prefLabel',
              page: {
                size: 100
              }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body
            tag2_item = json_data['@graph'].find { |item| item['@id'] == @tag2.id }

            assert_predicate(tag2_item, :present?)
            pref_label = tag2_item['skos:prefLabel']
            pref_label_value = pref_label.is_a?(Array) ? pref_label.find { |entry| entry['@language'] == 'de' }&.dig('@value') : pref_label

            assert_equal('Tag 2', pref_label_value)

            translated_thing_ids = DataCycleCore::Thing.where(id: @contents.pluck(:id)).with_locale('en').pluck(:id)
            json_data['@graph'].each do |item|
              expected_count = (@count_mapping[item['@id']] & translated_thing_ids).size

              assert_equal(expected_count, item['dc:thingCountWithSubtree'])
            end
          end

          # conceptFilter restricts the returned concepts (result set), unlike filter which drives the counts (#43008)
          test 'api/v4/endpoints/:endpoint/facets with conceptFilter[skos:broader] restricts returned concepts' do
            tag3 = @aliases.find_by(internal_name: 'Tag 3')
            nested1 = @aliases.find_by(internal_name: 'Nested Tag 1')
            nested2 = @aliases.find_by(internal_name: 'Nested Tag 2')

            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              conceptFilter: { attribute: { 'skos:broader': { in: [tag3.id] } } },
              page: { size: 100 }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            assert_equal([nested1.id, nested2.id].sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints/:endpoint/facets with conceptFilter[skos:broader]=null returns only top-level concepts' do
            roots = ['Tag 1', 'Tag 2', 'Tag 3'].map { |n| @aliases.find_by(internal_name: n).id }

            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              conceptFilter: { attribute: { 'skos:broader': { in: ['null'] } } },
              page: { size: 100 }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            assert_equal(roots.sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints/:endpoint/facets with conceptFilter[skos:ancestors] restricts to descendants' do
            tag3 = @aliases.find_by(internal_name: 'Tag 3')
            nested1 = @aliases.find_by(internal_name: 'Nested Tag 1')
            nested2 = @aliases.find_by(internal_name: 'Nested Tag 2')

            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              conceptFilter: { attribute: { 'skos:ancestors': { in: [tag3.id] } } },
              page: { size: 100 }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            assert_equal([nested1.id, nested2.id].sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints/:endpoint/facets with conceptFilter[search] restricts returned concepts' do
            nested1 = @aliases.find_by(internal_name: 'Nested Tag 1')
            nested2 = @aliases.find_by(internal_name: 'Nested Tag 2')

            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              conceptFilter: { search: 'Nested' },
              page: { size: 100 }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            assert_equal([nested1.id, nested2.id].sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints/:endpoint/facets conceptFilter restricts concepts while filter still drives counts' do
            roots = ['Tag 1', 'Tag 2', 'Tag 3'].map { |n| @aliases.find_by(internal_name: n).id }

            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              filter: { search: @tag2.id }, # counts: only the content tagged with Tag 2 matches
              conceptFilter: { attribute: { 'skos:broader': { in: ['null'] } } }, # concepts: roots only
              page: { size: 100 }
            }

            post api_v4_facets_path(params)
            json_data = response.parsed_body

            assert_equal(roots.sort, json_data['@graph'].pluck('@id').sort)
            json_data['@graph'].each do |item|
              assert_equal(item['@id'] == @tag2.id ? 1 : 0, item['dc:thingCountWithSubtree'])
            end
          end

          test 'api/v4/endpoints/:endpoint/facets rejects content-only filter keys inside conceptFilter' do
            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              conceptFilter: { classifications: { in: { withSubtree: [@tag1.id] } } }
            }

            post api_v4_facets_path(params)

            assert_response :bad_request
          end

          # dct:deleted is a no-op on facets (the count query excludes deleted concepts), so the
          # conceptFilter contract rejects it instead of silently ignoring it (#43008)
          test 'api/v4/endpoints/:endpoint/facets rejects conceptFilter[dct:deleted]' do
            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              conceptFilter: { attribute: { 'dct:deleted': { in: { bool: true } } } }
            }

            post api_v4_facets_path(params)

            assert_response :bad_request
          end

          # The id of the request scoped StoredFilter comes from DataCycleCore::UuidService. As the
          # view helper generate_uuid it was an instance method only on controllers including
          # DataCycleCore::ApiHelper, so every other build_search_query caller - facets among them -
          # raised NoMethodError once a user had a forced api_linked user_filter (#49238).
          test 'api/v4/endpoints/:endpoint/facets with a forced api_linked user_filter' do
            previous_user_filters = DataCycleCore.user_filters.deep_dup
            DataCycleCore.user_filters = { tmp_api_linked: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['api_linked'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['POI'] } }] } }

            params = {
              id: @endpoint.id,
              classification_tree_label_id: @tree_label.id,
              token: @current_user.access_token,
              page: { size: 100 }
            }

            post api_v4_facets_path(params)

            assert_response :success
            json_data = response.parsed_body

            json_data['@graph'].each do |item|
              assert_equal(@count_mapping[item['@id']].size, item['dc:thingCountWithSubtree'])
            end
          ensure
            DataCycleCore.user_filters = previous_user_filters
          end
        end
      end
    end
  end
end
