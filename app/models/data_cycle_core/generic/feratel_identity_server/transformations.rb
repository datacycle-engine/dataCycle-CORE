# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelIdentityServer
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::FeratelIdentityServer::TransformationFunctions[*args]
        end

        def self.user_to_organization(utility_object)
          t(:stringify_keys)
          .>> t(:nest, 'contact_info', ['email'])
          .>> t(:rename_keys, {
            'id' => 'external_key',
            'claims' => 'feratel_identity_claims',
            'username' => 'feratel_username',
            'legacyUsername' => 'feratel_legacy_username',
            'realm' => 'feratel_identity_realms',
            'dbCode' => 'feratel_identity_db_code',
            'role' => 'feratel_identity_role',
            'userType' => 'feratel_identity_user_type',
            'name' => 'tmp_name'
          })
          .>> t(:map_value, 'feratel_identity_realms', ->(v) { [v] })
          .>> t(:map_value, 'feratel_identity_db_code', ->(v) { [v] })
          .>> t(:map_value, 'feratel_identity_role', ->(v) { [v.to_s] })
          .>> t(:map_value, 'feratel_identity_user_type', ->(v) { [v.to_s] })
          .>> t(:add_field, 'feratel_identity_keywords', ->(s) { parse_tags(s) })
          .>> t(:add_field, 'name', ->(s) { s['tmp_name'].presence || '__unnamed_user__' })
          .>> t(:reject_keys, ['active', 'passwordExpired', 'emailConfirmed', 'userLocked', 'hasPassword', 'password', 'tmp_name'])
          .>> t(:flatten_hash_keys, 'feratel_identity_claims')
          .>> t(:tags_to_ids, 'feratel_identity_realms', utility_object.external_source.id, 'REALM:')
          .>> t(:tags_to_ids, 'feratel_identity_db_code', utility_object.external_source.id, 'dbCode:')
          .>> t(:tags_to_ids, 'feratel_identity_claims', utility_object.external_source.id, 'CLAIM:')
          .>> t(:tags_to_ids, 'feratel_identity_role', utility_object.external_source.id, 'ROLE:')
          .>> t(:tags_to_ids, 'feratel_identity_user_type', utility_object.external_source.id, 'userType:')
          .>> t(:tags_to_ids, 'feratel_identity_keywords', utility_object.external_source.id, "#{utility_object.external_source.config.dig('import_config', 'user_tags', 'external_id_prefix')} - ")
          .>> t(:strip_all)
        end

        def self.user_to_tags
          t(:add_field, 'tags', ->(s) { parse_tags(s) })
        end

        def self.parse_tags(s)
          s.select { |k, v| k.in?(['active', 'passwordExpired', 'emailConfirmed', 'userLocked', 'hasPassword']) && v }.keys.map(&:strip)
        end
      end
    end
  end
end
