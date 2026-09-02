# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V4
      class ExternalConnectionsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes
          @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'test-system-1')
          @other_system = DataCycleCore::ExternalSystem.find_by(identifier: 'base-system')
          # super_admin: holds create/remove_external_connection and switch/demote_primary_external_system
          @privileged_user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
          # admin: deliberately holds none of the four external connection abilities
          @restricted_user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
        end

        setup do
          @previous_user_filters = DataCycleCore.user_filters.deep_dup
          @content = create_content('Artikel', { name: "ExternalConnections #{SecureRandom.hex(6)}" })
          sign_in(@privileged_user)
        end

        teardown do
          DataCycleCore.user_filters = @previous_user_filters
        end

        # Installs a forced api scope user_filter for the privileged user's role that resolves to the
        # given content only (a filter parameter carrying 't' is taken over verbatim by
        # Type::StoredFilter::Parameters.param_from_definition).
        def scope_to_content(content)
          DataCycleCore.user_filters = {
            tmp_api_scope: {
              'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => [@privileged_user.role_name] }],
              'force' => true,
              'scope' => ['api'],
              'stored_filter' => [{ 't' => 'id', 'v' => { 'text' => content.id }, 'q' => 'internal', 'n' => 'id' }]
            }
          }
        end

        def identifiers(response_body)
          response_body['identifier']&.map { |i| [i['propertyID'], i['value'], i['valueReference']] } || []
        end

        # ---- create ----

        test 'POST external_connections adds a duplicate connection' do
          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :ok
          assert_equal @content.id, response.parsed_body['@id']
          assert_includes identifiers(response.parsed_body), [@external_system.identifier, 'ABC-123', 'duplicate']

          sync = @content.external_system_syncs.sole

          assert_equal @external_system.id, sync.external_system_id
          assert_equal 'duplicate', sync.sync_type
        end

        test 'POST external_connections accepts the external system uuid as propertyID' do
          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.id, value: 'ABC-123' }

          assert_response :ok
          assert_equal 1, @content.external_system_syncs.count
        end

        test 'POST external_connections prefers an identifier match over a name match' do
          # neither name nor identifier is unique in the schema, so propertyID can match two systems
          colliding = DataCycleCore::ExternalSystem.create!(name: @external_system.identifier, identifier: "colliding-#{SecureRandom.hex(4)}")

          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :ok
          assert_equal @external_system.id, @content.external_system_syncs.sole.external_system_id
        ensure
          colliding&.destroy
        end

        test 'POST external_connections is idempotent' do
          2.times do
            post api_v4_thing_external_connections_path(id: @content.id),
                 params: { propertyID: @external_system.identifier, value: 'ABC-123' }

            assert_response :ok
          end

          assert_equal 1, @content.external_system_syncs.count
        end

        test 'POST external_connections does not invalidate caches when nothing was added' do
          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :ok

          cache_valid_since = @content.reload.cache_valid_since

          # invalidate_self is a FOR UPDATE SKIP LOCKED bulk update over the content and everything
          # caching it, so the idempotent repeat must not trigger it again
          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :ok
          assert_equal cache_valid_since, @content.reload.cache_valid_since
        end

        test 'POST external_connections without value is a bad request' do
          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier }

          assert_response :bad_request
          assert_empty @content.external_system_syncs
        end

        test 'POST external_connections with an unknown external system is not found' do
          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: 'does-not-exist', value: 'ABC-123' }

          assert_response :not_found
          assert_empty @content.external_system_syncs
        end

        test 'POST external_connections for the primary connection is unprocessable' do
          @content.update_columns(external_source_id: @external_system.id, external_key: 'PRIMARY-1')

          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'PRIMARY-1' }

          assert_response :unprocessable_content
          assert_empty @content.external_system_syncs
        end

        test 'POST external_connections does not add a second connection next to an export one' do
          @content.external_system_syncs.create!(external_system_id: @external_system.id, external_key: 'EXP-1', sync_type: 'export')

          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'EXP-1' }

          assert_response :unprocessable_content
          assert_equal ['export'], @content.external_system_syncs.reload.pluck(:sync_type)
        end

        test 'POST external_connections without the ability is unauthorized' do
          sign_in(@restricted_user)

          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :unauthorized
          assert_empty @content.external_system_syncs
        end

        test 'POST external_connections without the ability does not reveal whether an external system exists' do
          sign_in(@restricted_user)

          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: 'does-not-exist', value: 'ABC-123' }

          assert_response :unauthorized
        end

        # ---- destroy ----

        test 'DELETE external_connections removes a duplicate connection' do
          @content.external_system_syncs.create!(external_system_id: @external_system.id, external_key: 'ABC-123', sync_type: 'duplicate')

          delete api_v4_thing_external_connections_path(id: @content.id, propertyID: @external_system.identifier, value: 'ABC-123')

          assert_response :ok
          assert_empty identifiers(response.parsed_body)
          assert_empty @content.external_system_syncs.reload
        end

        test 'DELETE external_connections is idempotent' do
          delete api_v4_thing_external_connections_path(id: @content.id, propertyID: @external_system.identifier, value: 'ABC-123')

          assert_response :ok
          assert_empty @content.external_system_syncs
        end

        test 'DELETE external_connections for the primary connection is unprocessable' do
          @content.update_columns(external_source_id: @external_system.id, external_key: 'PRIMARY-1')

          delete api_v4_thing_external_connections_path(id: @content.id, propertyID: @external_system.identifier, value: 'PRIMARY-1')

          assert_response :unprocessable_content
          assert_equal @external_system.id, @content.reload.external_source_id
        end

        test 'DELETE external_connections does not remove export connections' do
          @content.external_system_syncs.create!(external_system_id: @external_system.id, external_key: 'EXP-1', sync_type: 'export')

          delete api_v4_thing_external_connections_path(id: @content.id, propertyID: @external_system.identifier, value: 'EXP-1')

          assert_response :unprocessable_content
          assert_equal 1, @content.external_system_syncs.reload.count
        end

        test 'DELETE external_connections without the ability is unauthorized' do
          @content.external_system_syncs.create!(external_system_id: @external_system.id, external_key: 'ABC-123', sync_type: 'duplicate')
          sign_in(@restricted_user)

          delete api_v4_thing_external_connections_path(id: @content.id, propertyID: @external_system.identifier, value: 'ABC-123')

          assert_response :unauthorized
          assert_equal 1, @content.external_system_syncs.reload.count
        end

        # ---- promote ----

        test 'PATCH promote makes a duplicate connection the primary one and keeps the old primary' do
          @content.update_columns(external_source_id: @other_system.id, external_key: 'OLD-PRIMARY')
          @content.external_system_syncs.create!(external_system_id: @external_system.id, external_key: 'NEW-PRIMARY', sync_type: 'duplicate')

          patch api_v4_promote_thing_external_connections_path(id: @content.id),
                params: { propertyID: @external_system.identifier, value: 'NEW-PRIMARY' }

          assert_response :ok
          @content.reload

          assert_equal @external_system.id, @content.external_source_id
          assert_equal 'NEW-PRIMARY', @content.external_key
          # the previous primary is preserved as a duplicate connection, nothing is lost
          assert_includes identifiers(response.parsed_body), [@other_system.identifier, 'OLD-PRIMARY', 'duplicate']
          assert_includes identifiers(response.parsed_body), [@external_system.identifier, 'NEW-PRIMARY', 'import']
        end

        test 'PATCH promote for an unknown connection is not found' do
          patch api_v4_promote_thing_external_connections_path(id: @content.id),
                params: { propertyID: @external_system.identifier, value: 'MISSING' }

          assert_response :not_found
        end

        test 'PATCH promote for the current primary connection is unprocessable' do
          @content.update_columns(external_source_id: @external_system.id, external_key: 'PRIMARY-1')

          patch api_v4_promote_thing_external_connections_path(id: @content.id),
                params: { propertyID: @external_system.identifier, value: 'PRIMARY-1' }

          assert_response :unprocessable_content
        end

        test 'PATCH promote conflicting with another content is a conflict' do
          other_content = create_content('Artikel', { name: "ExternalConnections other #{SecureRandom.hex(6)}" })
          other_content.update_columns(external_source_id: @external_system.id, external_key: 'TAKEN')
          @content.external_system_syncs.create!(external_system_id: @external_system.id, external_key: 'TAKEN', sync_type: 'duplicate')

          patch api_v4_promote_thing_external_connections_path(id: @content.id),
                params: { propertyID: @external_system.identifier, value: 'TAKEN' }

          assert_response :conflict
          assert_nil @content.reload.external_source_id
        end

        test 'PATCH promote without the ability is unauthorized' do
          @content.external_system_syncs.create!(external_system_id: @external_system.id, external_key: 'ABC-123', sync_type: 'duplicate')
          sign_in(@restricted_user)

          patch api_v4_promote_thing_external_connections_path(id: @content.id),
                params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :unauthorized
          assert_nil @content.reload.external_source_id
        end

        # ---- demote ----

        test 'PATCH demote turns the primary connection into a duplicate connection' do
          @content.update_columns(external_source_id: @external_system.id, external_key: 'PRIMARY-1')

          patch api_v4_demote_thing_external_connections_path(id: @content.id)

          assert_response :ok
          @content.reload

          assert_nil @content.external_source_id
          assert_nil @content.external_key
          assert_includes identifiers(response.parsed_body), [@external_system.identifier, 'PRIMARY-1', 'duplicate']
        end

        test 'PATCH demote without a primary connection is unprocessable' do
          patch api_v4_demote_thing_external_connections_path(id: @content.id)

          assert_response :unprocessable_content
        end

        test 'PATCH demote without the ability is unauthorized' do
          @content.update_columns(external_source_id: @external_system.id, external_key: 'PRIMARY-1')
          sign_in(@restricted_user)

          patch api_v4_demote_thing_external_connections_path(id: @content.id)

          assert_response :unauthorized
          assert_equal @external_system.id, @content.reload.external_source_id
        end

        test 'external_connections without a signed in user is unauthorized' do
          # answered by the warden authenticate block the whole api namespace sits in (routes.rb), before
          # any controller code runs - the endpoints need no guard of their own for it
          sign_out(@privileged_user)

          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :unauthorized
          assert_empty @content.external_system_syncs
        end

        # ---- api scope ----

        test 'external_connections for a content outside the api scope is unauthorized' do
          other_content = create_content('Artikel', { name: "ExternalConnections Other #{SecureRandom.hex(6)}" })
          @content.update_columns(external_source_id: @external_system.id, external_key: 'PRIMARY-1')
          scope_to_content(other_content)

          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @other_system.identifier, value: 'ABC-123' }

          assert_response :unauthorized
          assert_empty @content.external_system_syncs

          patch api_v4_demote_thing_external_connections_path(id: @content.id)

          assert_response :unauthorized
          assert_equal @external_system.id, @content.reload.external_source_id
        end

        test 'external_connections inside the api scope are writable' do
          scope_to_content(@content)

          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :ok
          assert_equal 1, @content.external_system_syncs.count
        end

        # ---- embedded contents ----

        test 'external_connections of an embedded content are managed like those of any other' do
          @content.update_columns(content_type: 'embedded', external_source_id: @external_system.id, external_key: 'PRIMARY-1')
          # the dummy app configures a forced api scope for every role (valid_contents), and no api
          # scope contains embedded contents - see the next test, which is that case
          DataCycleCore.user_filters = {}

          # imports give embedded contents external keys of their own, and the backend runs all four
          # actions on them (ExternalConnectionsConcern checks no content_type) - the API must not be
          # stricter than the UI it mirrors
          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @other_system.identifier, value: 'ABC-123' }

          assert_response :ok
          assert_includes identifiers(response.parsed_body), [@other_system.identifier, 'ABC-123', 'duplicate']

          patch api_v4_demote_thing_external_connections_path(id: @content.id)

          assert_response :ok
          assert_nil @content.reload.external_source_id
        end

        test 'external_connections of an embedded content are out of reach for a caller with an api scope' do
          @content.update_column(:content_type, 'embedded')
          scope_to_content(@content)

          # an api scope never contains embedded contents - Filter::Search excludes them from its
          # default query - so the scope check answers 401, exactly like GET /api/v4/things/:id does
          post api_v4_thing_external_connections_path(id: @content.id),
               params: { propertyID: @other_system.identifier, value: 'ABC-123' }

          assert_response :unauthorized
          assert_empty @content.external_system_syncs
        end

        # ---- standard api parameters ----

        test 'external_connections accept the standard api v4 parameters' do
          # a client appending language/include/page generically to every request must not be rejected:
          # ApiBaseController permits these keys and prepare_url_parameters reads language itself
          post api_v4_thing_external_connections_path(id: @content.id, language: 'de', include: 'full', fields: 'name', sort: 'name', page: { size: 5 }, section: { meta: 0 }),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :ok
        end

        # ---- unknown thing ----

        test 'external_connections for an unknown thing is not found' do
          post api_v4_thing_external_connections_path(id: SecureRandom.uuid),
               params: { propertyID: @external_system.identifier, value: 'ABC-123' }

          assert_response :not_found
        end
      end
    end
  end
end
