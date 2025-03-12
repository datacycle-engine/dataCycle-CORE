# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Geo
        class << self
          def coordinates_to_value(computed_parameters:, computed_definition:, **_args)
            return unless computed_definition['compute']&.key?('key') || computed_parameters.values.first.blank?

            DataCycleCore::MasterData::DataConverter.string_to_geographic(computed_parameters.values.first).try(computed_definition.dig('compute', 'key'))
          end

          # :compute:
          #   :module: Geo
          #   :method: geoshape_from_concept
          #   :parameters:
          #     - administrative_areas_classifications
          # possible extensions:
          # - add a parameter to restrict to concept_scheme by name
          # - include mapped classifications
          def geoshape_from_concept(computed_parameters:, **_args)
            ids = computed_parameters.values.flatten
            return if ids.blank?

            sql = <<-SQL.squish
              SELECT ST_AsText(ST_Force3D(ST_Union(classification_polygons.geom))) AS geom
              FROM concepts
                INNER JOIN classification_polygons ON classification_polygons.classification_alias_id = concepts.id
              WHERE concepts.classification_id IN (?)
                AND classification_polygons.geom IS NOT NULL;
            SQL

            ActiveRecord::Base.connection
              .select_all(ActiveRecord::Base.send(:sanitize_sql_array, [sql, ids]))
              .cast_values
              .first
          end
        end
      end
    end
  end
end
