# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingsInCollections < Base
        attr_reader :subject, :conditions, :collection_ids

        def initialize(*collection_ids)
          @collection_ids = Array.wrap(collection_ids)
          things = DataCycleCore::Filter::Search.new(nil).union_filter_ids(@collection_ids).query
          @subject = DataCycleCore::Thing
          @conditions = { id: things.pluck(:id) }
        end

        private

        def to_restrictions(**)
          collections = DataCycleCore::Collection.where(id: @collection_ids).group_by(&:type)

          collections.flat_map do |k, v|
            to_restriction(
              collection_type: Object.const_get(k).model_name.human(count: v.size, locale:),
              collection_names_or_ids: v.map { |collection| "\"#{collection.name.presence || "[#{collection.id}]"}\"" }.join(', ')
            )
          end
        end
      end
    end
  end
end
