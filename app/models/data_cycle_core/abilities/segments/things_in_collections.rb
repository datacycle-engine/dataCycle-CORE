# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingsInCollections < Base
        attr_reader :subject

        def initialize(permission_key)
          @permission_key = permission_key
          @subject = DataCycleCore::Thing
        end

        def include?(content, *_args)
          @include ||= Hash.new do |h, key|
            h[key] = DataCycleCore::Filter::Search.new(nil)
              .union_filter_ids(key[1])
              .query
              .exists?(id: key[0])
          end

          @include[[content.id, collection_ids]]
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def collection_ids
          return @collection_ids if defined? @collection_ids

          @collection_ids = DataCycleCore::UserGroup.user_groups_with_permission(@permission_key).shared_collections.pluck(:id)
        end

        def to_restrictions(**)
          collections = DataCycleCore::UserGroup.user_groups_with_permission(@permission_key).shared_collections.group_by(&:class)

          collections.flat_map do |k, v|
            to_restriction(
              collection_type: k.model_name.human(count: v.size, locale:),
              collection_names_or_ids: v.map { |collection| "\"#{collection.name.presence || "[#{collection.id}]"}\"" }.join(', ')
            )
          end
        end
      end
    end
  end
end
