# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module RatingTransformations
        def self.collect_ratings(data, rating_configs, translation_key_prefix, external_source_id = nil)
          data.merge(
            {
              'aggregate_rating' => rating_configs.select { |rating_config|
                data[rating_config[0]] &&
                  (rating_config[1].nil? || data[rating_config[0]].to_f >= rating_config[1]) &&
                  (rating_config[2].nil? || data[rating_config[0]].to_f <= rating_config[2])
              }.map do |rating_config|
                external_key = [data['external_key'], rating_config[0]].join(' - ')
                {
                  'id' => (DataReferenceTransformations::ExternalReference.new(:content, external_source_id, external_key) if external_source_id && external_key),
                  'external_key' => external_key,
                  'name' => I18n.t(translation_key_prefix + rating_config[0], default: rating_config[0]),
                  'rating_value' => data[rating_config[0]],
                  'worst_rating' => rating_config[1],
                  'best_rating' => rating_config[2]
                }
              end
            }
          )
        end
      end
    end
  end
end
