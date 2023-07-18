# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationFacetsTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.where(template: false).delete_all
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
            json_data = JSON.parse(response.body)
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
                search: @tag1.id
              },
              page: {
                size: 100
              }
            }

            post api_v4_facets_path(params)
            json_data = JSON.parse(response.body)
            json_data['@graph'].each do |item|
              assert_equal(item['@id'] == @tag1.id ? 1 : 0, item['dc:thingCountWithSubtree'])
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
            json_data = JSON.parse(response.body)

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
            json_data = JSON.parse(response.body)
            json_data['@graph'].each do |item|
              assert_equal(tmp_mapping[item['@id']].size, item['dc:thingCountWithSubtree'])
            end
          end
        end
      end
    end
  end
end
