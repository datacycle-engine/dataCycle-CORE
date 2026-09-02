# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        # #50091: sort things by a prioritized list of classification_alias UUIDs
        class ClassificationTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes

            # CC BY 4.0 is a child of CC BY in the "Lizenzen" tree; CC BY-SA 4.0 and CC0 are separate.
            @cc_by = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY').first
            @cc_by40 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY 4.0').first
            @cc_by_sa40 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY-SA 4.0').first
            @cc0 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC0').first

            # minimal_poi has no embedded image, so each created content is a single top-level thing.
            create_poi = lambda do |classification_ids|
              poi = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
              data_hash = poi.get_data_hash
              data_hash['license_classification'] = classification_ids
              poi.set_data_hash(prevent_history: true, data_hash:)
              poi
            end

            @poi_cc_by40 = create_poi.call([@cc_by40.primary_classification.id])
            @poi_cc_by_sa40 = create_poi.call([@cc_by_sa40.primary_classification.id])
            @poi_cc0 = create_poi.call([@cc0.primary_classification.id])
            @poi_multi = create_poi.call([@cc_by_sa40.primary_classification.id, @cc0.primary_classification.id])
            @poi_none = create_poi.call([])
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/things sorted by dc:classification priority' do
            order = [@cc_by40.id, @cc_by_sa40.id, @cc0.id]
            post api_v4_things_path(sort: "dc:classification(#{order.join(',')})")

            ids = response.parsed_body['@graph'].pluck('@id')
            priority = {
              @poi_cc_by40.id => 1,
              @poi_cc_by_sa40.id => 2,
              @poi_multi.id => 2, # CC BY-SA 4.0 (2) + CC0 (3) -> earliest listed wins -> 2
              @poi_cc0.id => 3,
              @poi_none.id => nil # matches none of the listed classifications -> sorts last
            }
            positions = ids.map { |id| priority[id] }

            assert_equal(5, ids.size)
            assert_equal(positions.compact.sort, positions.compact, 'priorities must be ascending')
            assert_equal(positions.compact + positions.select(&:nil?), positions, 'non-matching content must sort last')
            assert_operator(ids.index(@poi_multi.id), :<, ids.index(@poi_cc0.id), 'earliest-listed classification wins')
          end

          test 'api/v4/things sorted by dc:classification is subtree-inclusive' do
            # @poi_cc_by40 is tagged with CC BY 4.0, a child of CC BY.
            post api_v4_things_path(sort: "dc:classification(#{@cc_by.id})")

            ids = response.parsed_body['@graph'].pluck('@id')

            assert_equal(@poi_cc_by40.id, ids.first, 'content tagged with a child concept matches the parent uuid')
            assert_operator(ids.index(@poi_cc_by40.id), :<, ids.index(@poi_none.id))
          end

          test 'api/v4/things sorted by reversed -dc:classification priority' do
            order = [@cc_by40.id, @cc_by_sa40.id, @cc0.id]
            post api_v4_things_path(sort: "-dc:classification(#{order.join(',')})")

            ids = response.parsed_body['@graph'].pluck('@id')

            assert_equal(@poi_none.id, ids.last, 'non-matching content still sorts last (NULLS LAST)')
            assert_operator(ids.index(@poi_cc0.id), :<, ids.index(@poi_cc_by40.id), 'priority is reversed')
          end

          test 'api/v4/things sort dc:classification without uuids is rejected' do
            post api_v4_things_path(sort: 'dc:classification()')

            assert_response(:bad_request)
          end

          test 'api/v4/things sort dc:classification with invalid uuid is rejected' do
            post api_v4_things_path(sort: 'dc:classification(not-a-uuid)')

            assert_response(:bad_request)
          end

          # #50091 security: a SQL-injection payload in the sort value must be rejected as a clean
          # 400 (not a 500 and not executed) — the uuid? check blocks it before it reaches SQL.
          test 'api/v4/things sort dc:classification with a sql injection payload is rejected' do
            things_before = DataCycleCore::Thing.count

            post api_v4_things_path(sort: "dc:classification(#{@cc0.id}'); DROP TABLE things; --)")

            assert_response(:bad_request)
            assert_equal(things_before, DataCycleCore::Thing.count, 'things table must be untouched')
          end
        end
      end
    end
  end
end
