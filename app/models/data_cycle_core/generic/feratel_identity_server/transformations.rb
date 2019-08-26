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
          .>> t(:rename_keys, 'id' => 'external_key')
          .>> t(:rename_keys, 'claims' => 'feratel_identity_claims')
          .>> t(:add_field, 'feratel_identity_keywords', ->(s) { parse_tags(s) })
          .>> t(:reject_all_keys, except: ['email', 'name', 'external_key', 'feratel_identity_keywords', 'feratel_identity_claims'])
          .>> t(:flatten_hash_keys, 'feratel_identity_claims')
          .>> t(:tags_to_ids, 'feratel_identity_claims', utility_object.external_source.id, 'CLAIM:')
          .>> t(:tags_to_ids, 'feratel_identity_keywords', utility_object.external_source.id, "#{utility_object.external_source.config.dig('import_config', 'user_tags', 'external_id_prefix')} - ")
          .>> t(:strip_all)
        end

        def self.user_to_tags
          t(:add_field, 'tags', ->(s) { parse_tags(s) })
        end

        def self.parse_tags(s)
          s.select { |k, v| k.in?(['active', 'passwordExpired', 'emailConfirmed', 'userLocked']) && v }.keys.map(&:strip)
        end
      end
    end
  end
end
