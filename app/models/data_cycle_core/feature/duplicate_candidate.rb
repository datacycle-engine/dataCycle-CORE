# frozen_string_literal: true

module DataCycleCore
  module Feature
    class DuplicateCandidate < Base
      EXCEPT_PROPERTIES = ['id', 'external_key', 'slug', 'date_created', 'date_modified', 'date_deleted'].freeze
      WEIGHTING = 5
      DISTANCE_METERS = 100
      DISTANCE_METERS_NAME_GEO = 10

      class << self
        def content_module
          DataCycleCore::Feature::Content::DuplicateCandidate
        end

        def data_hash_module
          DataCycleCore::Feature::DataHash::DuplicateCandidate
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::DuplicateCandidate
        end

        def routes_module
          DataCycleCore::Feature::Routes::DuplicateCandidate
        end

        def find_duplicates(content)
          duplicate_methods = duplicate_method(content)
          return if duplicate_methods.blank?

          duplicates = []
          duplicate_methods.each do |dm|
            duplicates.concat(Array.wrap(send(dm, content)))
          end

          duplicates.sort_by! { |t| -t[:score] }
          duplicates.uniq! { |t| t[:thing_duplicate_id] }

          duplicates
        end

        def find_duplicates_for_contents(contents)
          duplicates = []

          contents.thing_templates.each do |template|
            things = contents.where(template_name: template.template_name)

            duplicate_methods = duplicate_method(template.template_thing)
            next if duplicate_methods.blank?

            duplicate_methods.each do |dm|
              duplicates.concat(Array.wrap(send(dm, things)))
            end
          end

          duplicates.sort_by! { |t| -t[:score] }
          duplicates.uniq! { |t| t[:thing_id] }
          duplicates
        end

        def content_ids(content)
          content.is_a?(ActiveRecord::Relation) ? content.pluck(:id) : content.id
        end

        def duplicate_method(content)
          return unless enabled?

          Array.wrap(configuration(content)['method'])
        end

        # specific implementiations of duplicatemethods
        def bild_duplicate(content)
          content.asset&.duplicate_candidates_with_score
        end

        def only_title_duplicate(content)
          return if content.name.blank?

          DataCycleCore::Thing
            .joins(:translations)
            .where(template_name: content.template_name)
            .where("thing_translations.content ->> 'name' = ?", content.name)
            .where.not(id: content.id)
            .pluck(:id)
            .filter_map { |d| { thing_duplicate_id: d, method: 'only_title', score: 83 } }
        end

        def data_metric_hamming(content)
          except = EXCEPT_PROPERTIES + content.linked_property_names + content.embedded_property_names + content.classification_property_names
          relevant_schema = content.schema.dup
          relevant_schema['properties'] = relevant_schema['properties'].except(*except)
          total = relevant_schema['properties'].size
          duplicates = DataCycleCore::Thing.where(
            template_name: content.template_name
          ).joins(:translations).where(
            "thing_translations.locale = 'de'"
          ).where( # prefilter with name
            "similarity(thing_translations.content ->> 'name', ?) > 0.8", content.name
          )

          if content.primary_geometry.present?
            duplicates = duplicates.joins(:primary_geometry)
              .where(
                "ST_DWithin(geometries.geom_simple, ST_GeographyFromText(?), #{DISTANCE_METERS})",
                "SRID=4326;#{content.primary_geometry.geom_simple}"
              )
          else
            duplicates = duplicates.where.not(
              DataCycleCore::Geometry.primary.where('geometries.thing_id = things.id').select(1).arel.exists
            )
          end

          duplicates.where.not(id: content.id)
            .filter_map do |d|
              diff = content.diff(d.get_data_hash.except(*except), relevant_schema)
              score = [0, 100 * (total - (diff.size * WEIGHTING)) / total].max
              { thing_duplicate_id: d.id, method: 'data_metric_hamming', score: } if score > 80
            end
        end

        def data_metric_name_geo(content)
          duplicates = DataCycleCore::Thing.where(
            template_name: content.template_name,
            name: content.name
          )

          if content.primary_geometry.present?
            duplicates = duplicates.joins(:primary_geometry)
              .where(
                "ST_DWithin(geometries.geom_simple, ST_GeographyFromText(?), #{DISTANCE_METERS_NAME_GEO})",
                "SRID=4326;#{content.primary_geometry.geom_simple}"
              )
          else
            duplicates = duplicates.where.not(
              DataCycleCore::Geometry.primary.where('geometries.thing_id = things.id').arel.exists
            )
          end

          duplicates.where.not(id: content.id)
            .pluck(:id)
            .filter_map { |d| { thing_duplicate_id: d, method: 'data_metric_name_geo', score: 83 } }
        end

        def version_name_for_merge(duplicate, ui_locale = DataCycleCore.ui_locales.first)
          I18n.t('common.merged_with_version_name', name: I18n.with_locale(duplicate.first_available_locale) { duplicate.title }, id: duplicate.id, locale: ui_locale)
        end
      end
    end
  end
end
