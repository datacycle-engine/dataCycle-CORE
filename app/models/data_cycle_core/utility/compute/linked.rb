# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Linked
        extend Extensions::ValueByPathExtension
        TEXT_DATA_HREF_REGEX = /data-href="([0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12})"/

        class << self
          def from_geo_shape(content:, computed_parameters:, computed_definition:, **_args)
            values = []
            computed_definition.dig('compute', 'parameters')&.each do |parameter_key|
              location_value = Array.wrap(get_values_from_hash(data: computed_parameters, key_path: parameter_key.split('.'))).first

              next if location_value.blank?

              if location_value.is_a?(::String)
                values << location_value
              else
                value = DataCycleCore::MasterData::DataConverter.geographic_to_string(location_value)
                next if value.blank?
                values << value
              end
            end

            return if values.empty?

            valid_things = DataCycleCore::StoredFilter.from_property_definition(computed_definition).things
            valid_things = valid_things.where.not(id: content.id) if content.present?

            values.map { |value| get_ids_from_geometry(things: valid_things, geometry: value.to_s) }
              .flatten
              .compact_blank
              .uniq
          end

          def linked_from_text(content:, computed_parameters:, **_args)
            ids = []

            computed_parameters.each_value do |parameter|
              ids.concat(get_ids_from_text(parameter)) if parameter.is_a?(::String)
            end

            content.available_locales.except(I18n.locale).each do |locale|
              I18n.with_locale(locale) do
                computed_parameters.each_key do |key|
                  value = content.try(key)
                  ids.concat(get_ids_from_text(value)) if value.is_a?(::String)
                end
              end
            end

            ids.uniq
          end

          private

          def get_ids_from_text(text)
            ids = []

            text&.scan(TEXT_DATA_HREF_REGEX) do |match|
              id = match.first

              ids << id if id.present? && ids.exclude?(id)
            end

            ids
          end

          def get_ids_from_geometry(things:, geometry:)
            query_sql = <<-SQL.squish
              SELECT things.id
              FROM things
              WHERE things.id IN (#{things.select(:id).reorder(nil).to_sql})
                AND ST_Intersects (things.geom_simple, ST_GeomFromText (:geo, 4326))
            SQL

            ActiveRecord::Base.connection.select_all(
              ActiveRecord::Base.send(
                :sanitize_sql_array, [
                  query_sql,
                  { geo: geometry }
                ]
              )
            ).rows.flatten
          end
        end
      end
    end
  end
end
