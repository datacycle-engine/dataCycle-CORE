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

          # Returns the linked ids of the first parameter minus the linked ids
          # of all following parameters. Used to combine an automatically
          # computed linked set with a manually maintained exclusion list.
          #
          # @param computed_parameters [Hash] linked values keyed by attribute
          # @return [Array<String>] base ids without the excluded ids
          # @example YAML schema configuration
          #   :dc_linked_protected_areas:
          #     :type: linked
          #     :compute:
          #       :module: Linked
          #       :method: difference
          #       :parameters:
          #         - dc_linked_protected_areas_automatic
          #         - dc_excluded_protected_areas
          def difference(computed_parameters:, computed_definition:, **_args)
            parameter_keys = Array.wrap(computed_definition.dig('compute', 'parameters'))
            return [] if parameter_keys.blank?

            base_ids = extract_ids(computed_parameters[parameter_keys.first])
            return base_ids if base_ids.blank?

            excluded_ids = parameter_keys.drop(1).flat_map { |key| extract_ids(computed_parameters[key]) }

            base_ids - excluded_ids
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

          # Links to parent website by traversing content_content_links recursively.
          # Uses a recursive CTE following 'linked_thing', 'submenu', or 'main_menu' relations to find the parent Website.
          #
          # @param computed_parameters [Hash] Parameters containing linked content IDs
          # @return [Array<String>] Array of Website IDs found in the parent hierarchy
          # @example YAML schema configuration
          #   :dc_website:
          #     :type: linked
          #     :compute:
          #       :module: Linked
          #       :method: website
          #       :parameters:
          #         - is_linked_to
          def website(computed_parameters:, **_args)
            sql = <<~SQL.squish
              WITH recursive base AS (
                SELECT ccl.content_a_id,
                  ccl.relation AS relation,
                  ARRAY [ccl.content_b_id] AS "path"
                FROM content_content_links ccl
                WHERE ccl.content_b_id IN (?)
                UNION
                SELECT ccl.content_a_id,
                  ccl.relation AS relation,
                  (base."path" || ARRAY [ccl.content_b_id]) AS "path"
                FROM content_content_links ccl
                  JOIN base ON base.content_a_id = ccl.content_b_id
                WHERE ccl.relation IN ('submenu', 'main_menu', 'linked_thing')
                  AND ccl.content_a_id <> ALL(base."path")
              )
              SELECT things.id AS id
              FROM base
                JOIN things ON things.id = base.content_a_id
              WHERE things.template_name = 'Website';
            SQL

            ids = computed_parameters.values.flatten.uniq
            sanitized_sql = ActiveRecord::Base.send(:sanitize_sql_array, [sql, ids])
            ActiveRecord::Base.connection.select_all(sanitized_sql).pluck('id')
          end

          private

          def extract_ids(value)
            Array.wrap(value).map { |v|
              if v.is_a?(::Hash)
                v['id'] || v[:id]
              elsif v.respond_to?(:id)
                v.id
              else
                v
              end
            }.compact_blank.uniq
          end

          def get_ids_from_text(text)
            ids = []

            text&.scan(TEXT_DATA_HREF_REGEX) do |match|
              id = match.first

              ids << id if id.present? && ids.exclude?(id)
            end

            ids
          end

          def get_ids_from_geometry(things:, geometry:)
            query_sql = <<~SQL.squish
              SELECT DISTINCT geometries.thing_id
              FROM geometries
              WHERE geometries.thing_id IN (#{things.select(:id).reorder(nil).to_sql})
                AND ST_Intersects (geometries.geom_simple, ST_GeomFromText (:geo, 4326))
                AND geometries.is_primary = true
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
