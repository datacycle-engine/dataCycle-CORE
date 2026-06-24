# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingsByCollections < Base
        attr_reader :subject

        def initialize(*collection_ids)
          @collection_ids = Array.wrap(collection_ids).flatten.map(&:to_s)
          @subject = DataCycleCore::Thing
        end

        def include?(content, *_args)
          return false if @collection_ids.empty?

          DataCycleCore::Collection.where(id: @collection_ids)
            .things
            .exists?(id: content.id)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def to_restrictions(**)
          collections = DataCycleCore::Collection.where(id: @collection_ids).group_by(&:class)

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
