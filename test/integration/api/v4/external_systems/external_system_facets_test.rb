# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module ExternalSystems
        class ExternalSystemFacetsTest < DataCycleCore::V4::Base
          SQL_INJECTION_PAYLOADS = [
            '1); DROP TABLE things; --',
            "' OR '1'='1",
            "'); DELETE FROM things WHERE ('1'='1",
            "00000000-0000-0000-0000-000000000000' OR '1'='1"
          ].freeze

          before(:all) do
            DataCycleCore::Thing.delete_all
            @current_user = User.find_by(email: 'tester@datacycle.at')
            @current_user.update(access_token: SecureRandom.hex)
            @endpoint = DataCycleCore::StoredFilter.create(api: true, user: @current_user)

            @system_a = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
            @system_b = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-2')

            # 3 contents imported from system_a, 1 from system_b, 1 without a primary source
            @contents_a = Array.new(3) { |i| create_imported_content("a-#{i}", @system_a) }
            @contents_b = [create_imported_content('b-0', @system_b)]
            @content_without_source = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { 'name' => 'no-source' })
          end

          def create_imported_content(key, external_system)
            content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { 'name' => key })
            content.update_columns(external_source_id: external_system.id, external_key: key)
            content
          end

          test 'api/v4/endpoints/:endpoint/facets/externalSystems counts contents per external system, sorted by count' do
            post api_v4_external_systems_facets_path(id: @endpoint.id, token: @current_user.access_token)

            assert_response :success
            graph = response.parsed_body['@graph']

            # sorted by count desc: system_a (3) before system_b (1)
            assert_equal([@system_a.identifier, @system_b.identifier], graph.pluck('@id'))

            counts = graph.index_by { |i| i['@id'] }.transform_values { |i| i['dc:thingCount'] }

            assert_equal(3, counts[@system_a.identifier])
            assert_equal(1, counts[@system_b.identifier])

            # the content without a primary source is not counted
            assert_equal(4, graph.sum { |i| i['dc:thingCount'] })
          end

          test 'api/v4/endpoints/:endpoint/facets/externalSystems honors minCount' do
            post api_v4_external_systems_facets_path(id: @endpoint.id, token: @current_user.access_token, minCount: 2)

            assert_equal([@system_a.identifier], response.parsed_body['@graph'].pluck('@id'))
          end

          test 'api/v4/endpoints/:endpoint/things filtered by external system uuid' do
            post api_v4_stored_filter_things_path(id: @endpoint.id, token: @current_user.access_token, filter: { externalSystem: { in: [@system_b.id] } })

            assert_equal(@contents_b.pluck(:id).sort, response.parsed_body['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints/:endpoint/things filtered by external system identifier' do
            post api_v4_stored_filter_things_path(id: @endpoint.id, token: @current_user.access_token, filter: { externalSystem: { in: [@system_a.identifier] } })

            assert_equal(@contents_a.pluck(:id).sort, response.parsed_body['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints/:endpoint/things excluding an external system' do
            post api_v4_stored_filter_things_path(id: @endpoint.id, token: @current_user.access_token, filter: { externalSystem: { notIn: [@system_a.identifier] } })

            ids = response.parsed_body['@graph'].pluck('@id')

            assert_includes(ids, @contents_b.first.id)
            assert_includes(ids, @content_without_source.id)
            assert_empty(ids & @contents_a.pluck(:id))
          end

          # ---------- SQL injection hardening ----------
          test 'facets endpoint is not vulnerable to SQL injection via minCount' do
            thing_count = DataCycleCore::Thing.count

            SQL_INJECTION_PAYLOADS.each do |payload|
              post api_v4_external_systems_facets_path(id: @endpoint.id, token: @current_user.access_token, minCount: payload)

              assert_response :success, "unexpected status for minCount payload: #{payload}"
              assert_equal(thing_count, DataCycleCore::Thing.count, "things table changed for minCount payload: #{payload}")
            end
          end

          test 'facets endpoint is not vulnerable to SQL injection via the external system filter' do
            thing_count = DataCycleCore::Thing.count
            allowed_ids = [@system_a.identifier, @system_b.identifier]

            SQL_INJECTION_PAYLOADS.each do |payload|
              post api_v4_external_systems_facets_path(id: @endpoint.id, token: @current_user.access_token, filter: { externalSystem: { in: [payload] } })

              assert_response :success, "unexpected status for facet filter payload: #{payload}"
              assert_equal(thing_count, DataCycleCore::Thing.count, "things table changed for facet filter payload: #{payload}")
              assert_empty(response.parsed_body['@graph'].pluck('@id') - allowed_ids, "unexpected external system surfaced for payload: #{payload}")
            end
          end

          test 'things endpoint is not vulnerable to SQL injection via the external system filter' do
            thing_count = DataCycleCore::Thing.count

            SQL_INJECTION_PAYLOADS.each do |payload|
              post api_v4_stored_filter_things_path(id: @endpoint.id, token: @current_user.access_token, filter: { externalSystem: { in: [payload] } })

              assert_response :success, "unexpected status for things filter payload: #{payload}"
              assert_equal(thing_count, DataCycleCore::Thing.count, "things table changed for things filter payload: #{payload}")
            end
          end
        end
      end
    end
  end
end
