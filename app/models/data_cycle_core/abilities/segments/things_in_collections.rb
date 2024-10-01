# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingsInCollections < Base
        attr_reader :subject, :template_names

        def initialize(permission_key, template_names = [])
          @permission_key = permission_key
          @template_names = Array.wrap(template_names)
          @subject = DataCycleCore::Thing
        end

        def conditions
          collections = collection_ids
          thing_ids = DataCycleCore::Filter::Search.new(nil).union_filter_ids(collections).query.pluck(:id)

          if collection_ids.any? && @template_names.empty?
            condition = { id: thing_ids }
          elsif @template_names.any? && collections.empty?
            condition = { template_name: @template_names }
          elsif @template_names.present? && collections.any?
            condition = { id: thing_ids, template_name: @template_names }
          end
          condition
        end

        private

        def collection_ids(permission_key = @permission_key)
          user_group_w_keys = DataCycleCore::UserGroup.user_groups_with_permission(permission_key)
          return [] if user_group_w_keys.blank?
          user_group_w_keys.flat_map(&:shared_collection_ids) || []
        end

        def to_restrictions(**)
          collections = DataCycleCore::UserGroup.user_groups_with_permission(@permission_key).flat_map(&:shared_collections).group_by(&:type)

          collections.flat_map do |k, v|
            template_names = I18n.t('common.contents.other', locale:)
            template_names += " (#{@template_names.join(', ')})" if @template_names.present?

            to_restriction(
              template_names:,
              collection_type: Object.const_get(k).model_name.human(count: v.size, locale:),
              collection_names_or_ids: v.map { |collection| "\"#{collection.name.presence || "[#{collection.id}]"}\"" }.join(', ')
            )
          end
        end
      end
    end
  end
end
