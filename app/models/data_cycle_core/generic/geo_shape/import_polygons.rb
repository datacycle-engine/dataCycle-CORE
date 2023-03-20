# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoShape
      module ImportPolygons
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc.curry[options],
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, locale, options, source_filter = nil)
          if source_filter.present?
            mongo_item.where(source_filter.with_evaluated_values)
          elsif options.dig(:import, :tag_root_source_filter).present?
            mongo_item.where(options.dig(:import, :tag_root_source_filter).with_evaluated_values)
          elsif options.dig(:import, :tag_parent_id_path).present?
            mongo_item.where("dump.#{locale}.#{options.dig(:import, :tag_parent_id_path)}": nil)
          end
        end

        def self.load_child_classifications(options, mongo_item, parent_data, locale = 'de', source_filter = nil)
          if source_filter.present?
            mongo_item.where(
              source_filter.with_evaluated_values.merge(
                "dump.#{locale}.#{options.dig(:import, :tag_parent_id_path)}": parent_data.dig(options.dig(:import, :tag_id_path))
              )
            )
          else
            mongo_item.where(
              "dump.#{locale}.#{options.dig(:import, :tag_parent_id_path)}": parent_data.dig(options.dig(:import, :tag_id_path))
            )
          end
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, options = {})
          return nil if raw_data.dig(options.dig(:import, :tag_parent_id_path)).blank?

          DataCycleCore::Classification
            .for_tree(options.dig(:import, :tree_label))
            .find_by(
              external_source_id: external_source_id,
              external_key: "GeoShape - #{raw_data.dig(options.dig(:import, :tag_parent_id_path))}"
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(options, raw_data)
          geometry = raw_data.dig(options.dig(:import).key?(:tag_geom_path) ? options.dig(:import, :tag_geom_path) : 'geom')

          {
            external_key: "GeoShape - #{raw_data.dig(options.dig(:import, :tag_id_path))}",
            name: raw_data.dig(options.dig(:import, :tag_name_path))
          }.merge(geometry.present? ? { classification_polygons_attributes: [{ geom: geometry }] } : { assignable: false })
        end
      end
    end
  end
end
