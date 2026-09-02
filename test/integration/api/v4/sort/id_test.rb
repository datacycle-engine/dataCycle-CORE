# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        # #50554: sort things by a prioritized list of content UUIDs
        class IdTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes

            # minimal_poi has no embedded image, so each created content is a single top-level thing.
            # sorted by id, so the permutation below can never coincide with the plain id sort (uuids are random)
            @contents = Array.new(4) { DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi') }.sort_by(&:id)
            @order = [2, 0, 3, 1].map { |i| @contents[i].id }
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          def graph_ids(params)
            post api_v4_things_path(params)

            response.parsed_body['@graph'].pluck('@id')
          end

          test 'api/v4/things sorted by @id keeps the given order' do
            assert_equal(@order, graph_ids(sort: "@id(#{@order.join(',')})"))
          end

          test 'api/v4/things sorted by @id ranks unlisted content last' do
            listed = @order.first(2)
            unlisted = @order.last(2)

            ids = graph_ids(sort: "@id(#{listed.join(',')})")

            assert_equal(listed, ids.first(2))
            assert_equal(unlisted.sort, ids.last(2).sort)
          end

          test 'api/v4/things sorted by reversed -@id reverses the given order' do
            assert_equal(@order.reverse, graph_ids(sort: "-@id(#{@order.join(',')})"))
          end

          test 'api/v4/things sorted by @id combined with the contentId filter' do
            expected = @order.first(3)
            # contentId expects ONE comma-separated string; separate array entries are ANDed
            params = { sort: "@id(#{expected.join(',')})", filter: { contentId: { in: [expected.join(',')] } } }

            assert_equal(expected, graph_ids(params))
          end

          # #50554 (#50555): the Voicebot builds a collection from its search hits, so an explicit
          # @id sort has to win over the collection's own manual order.
          test 'api/v4/endpoints sorted by @id overrides the collection manual order' do
            collection = DataCycleCore::TestPreparations.create_watch_list(name: 'Sortierung nach vorgegebenen IDs')
            collection.update_column(:manual_order, true)
            @contents.each { |c| c.watch_lists << collection }
            collection.update_order_by_array(@contents.map(&:id))

            post api_v4_stored_filter_path(id: collection.id, sort: "@id(#{@order.join(',')})", fields: '@id')

            assert_equal(@order, response.parsed_body['@graph'].pluck('@id'))
          end

          # #50554: without a list @id sorts by the uuid itself instead of being silently ignored.
          test 'api/v4/things sorted by @id without a list sorts by id' do
            expected = @contents.map(&:id).sort

            assert_equal(expected, graph_ids(sort: '@id'))
            assert_equal(expected.reverse, graph_ids(sort: '-@id'))
          end

          test 'api/v4/things sort @id with invalid uuid is rejected' do
            post api_v4_things_path(sort: '@id(not-a-uuid)')

            assert_response(:bad_request)
          end

          # #50554 security: a SQL-injection payload in the sort value must be rejected as a clean
          # 400 (not a 500 and not executed) — the uuid? check blocks it before it reaches SQL.
          test 'api/v4/things sort @id with a sql injection payload is rejected' do
            things_before = DataCycleCore::Thing.count

            post api_v4_things_path(sort: "@id(#{@contents.first.id}'); DROP TABLE things; --)")

            assert_response(:bad_request)
            assert_equal(things_before, DataCycleCore::Thing.count, 'things table must be untouched')
          end
        end
      end
    end
  end
end
