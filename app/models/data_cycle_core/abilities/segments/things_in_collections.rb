# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingsInCollections < Base
        attr_reader :subject, :conditions, :collection_ids, :template_names

        def initialize(collection_ids = [], template_names = [])
          @collection_ids = Array.wrap(collection_ids)
          @template_names = Array.wrap(template_names)
          things = DataCycleCore::Filter::Search.new(nil).union_filter_ids(@collection_ids).query.select(:id)
          @subject = DataCycleCore::Thing
          @conditions =
            if @collection_ids.any? && @template_names.empty?
              { id: things.ids }
            elsif @template_names.any? && @collection_ids.empty?
              { template_name: @template_names }
            elsif @template_names.present? && @collection_ids.any?
              { id: things.ids, template_name: @template_names }
            end
        end

        private

        def to_restrictions(**)
          collections = DataCycleCore::Collection.where(id: @collection_ids).group_by(&:type)

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
