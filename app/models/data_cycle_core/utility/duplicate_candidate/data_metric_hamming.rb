# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class DataMetricHamming < Base
        EXCEPT_PROPERTIES = ['slug', 'date_created', 'date_modified', 'date_deleted'].freeze
        WEIGHTING = 5
        DISTANCE_METERS = 100
        PARAMETERS = ['name'].freeze

        class << self
          # Narrows by trigram similarity of the name first, then scores how much of the rest of the
          # schema two contents share. The name half goes through Base.same_locale_scope like every
          # other name rule; before that this module compared `content.name` - read in the current
          # locale - against a hard-coded 'de' translation, which crossed the two whenever the
          # current locale was anything else.
          #
          # `preload` rather than the `includes`/`references` pair it replaces: both load the
          # association, but `references` folds the load into the filtering join, so a candidate
          # would carry only the locale the scope filtered by. Today that is the locale
          # `get_data_hash_partial` reads anyway - nothing changes locale between building the
          # relation and reading it - so `preload` buys independence of the two at the price of
          # loading every locale, not a translation the pair it replaces would have missed.
          #
          # @param content [DataCycleCore::Thing] content to find candidates for
          # @return [Array<Hash>, nil] candidate rows scored by schema overlap, nil when the content
          #   has no name in the current locale
          def duplicates(content:, **)
            return if content.name.blank?

            relevant_schema = relevant_schema(content)
            total = relevant_schema['properties'].size
            relevant_prop_names = relevant_schema['properties'].keys

            name_min_score = duplicate_parameter(content, 'name_min_score') || 0.8
            duplicates = same_locale_scope(content)
              .preload(:translations)
              .where("similarity(thing_translations.content ->> 'name', ?) > ?", content.name, name_min_score)

            duplicates = if content.primary_geometry.present?
                           duplicates.joins(:primary_geometry)
                             .where(
                               "ST_DWithin(geometries.geom_simple, ST_GeographyFromText(?), #{DISTANCE_METERS})",
                               "SRID=4326;#{content.primary_geometry.geom_simple}"
                             )
                         else
                           duplicates.where.not(
                             DataCycleCore::Geometry.primary.where('geometries.thing_id = things.id').select(1).arel.exists
                           )
                         end

            content_min_score = duplicate_parameter(content, 'content_min_score')&.*(100) || 80
            duplicates.filter_map do |d|
              diff = content.diff(d.get_data_hash_partial(relevant_prop_names), relevant_schema)
              score = [0, 100 * (total - (diff.size * WEIGHTING)) / total].max
              { thing_duplicate_id: d.id, method: identifier, score: } if score > content_min_score
            end
          end

          def parameters(content:, **)
            (super + Array.wrap(relevant_schema(content)&.dig('properties')&.keys)).uniq
          end

          private

          def duplicate_parameter(content, parameter)
            return unless feature.enabled?

            feature.configuration(content).dig('parameters', parameter)
          end

          def relevant_schema(content)
            except = EXCEPT_PROPERTIES +
                     content.internal_property_names +
                     content.linked_property_names +
                     content.embedded_property_names +
                     content.classification_property_names +
                     content.virtual_property_names
            relevant_schema = content.schema.dup
            relevant_schema['properties'] = relevant_schema['properties'].except(*except)
            relevant_schema
          end
        end
      end
    end
  end
end
