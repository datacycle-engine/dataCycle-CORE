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

        def find_duplicates(content)
          method = duplicate_method(content)
          return nil if method.blank?
          send(method, content)
        end

        def duplicate_method(content)
          return unless enabled?

          configuration(content).dig('method') || nil
        end

        # specific implementiations of duplicatemethods
        def bild_duplicate(content)
          content.asset&.duplicate_candidates_with_score
        end

        def only_title_duplicate(content)
          DataCycleCore::Thing.where(
            template: false,
            template_name: content.template_name,
            name: content.name
          ).where.not(id: content.id)
            .pluck(:id)
            .map { |d| { thing_duplicate_id: d, method: 'only_title', score: 83 } }
            .compact
        end

        def data_metric_hamming(content)
          except = EXCEPT_PROPERTIES + content.linked_property_names + content.embedded_property_names + content.classification_property_names
          relevant_schema = content.schema.dup
          relevant_schema['properties'] = relevant_schema.dig('properties').except(*except)
          total = relevant_schema['properties'].size
          DataCycleCore::Thing.where(
            template: false,
            template_name: content.template_name
          ).joins(:translations).where(
            "thing_translations.locale = 'de'"
          ).where( # prefilter with name
            'similarity(thing_translations.name, ?) > 0.8', content.name
          ).where( # prefilter location
            content.location.blank? ? 'location IS NULL' : "ST_DWithin(location, ST_GeographyFromText('SRID=4326;#{content.location&.to_s}'), #{DISTANCE_METERS})"
          ).where.not(id: content.id)
            .map { |d|
              diff = content.diff(d.get_data_hash.except(*except), relevant_schema)
              score = [0, 100 * (total - diff.size * WEIGHTING) / total].max
              { thing_duplicate_id: d.id, method: 'data_metric_hamming', score: score } if score > 80
            }.compact
        end

        def data_metric_name_geo(content)
          DataCycleCore::Thing.where(
            template: false,
            template_name: content.template_name,
            name: content.name
          ).where( # prefilter location
            content.location.blank? ? 'location IS NULL' : "ST_DWithin(location, ST_GeographyFromText('SRID=4326;#{content.location&.to_s}'), #{DISTANCE_METERS_NAME_GEO})"
          ).where.not(id: content.id)
          .pluck(:id)
          .map { |d| { thing_duplicate_id: d, method: 'data_metric_name_geo', score: 83 } }
          .compact
        end
      end
    end
  end
end
