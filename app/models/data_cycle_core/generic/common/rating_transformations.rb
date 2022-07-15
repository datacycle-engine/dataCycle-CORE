# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module RatingTransformations
        def self.collect_ratings(data, rating_configs, translation_key_prefix)
          data.merge(
            {
              'aggregate_rating' => rating_configs.select { |rating_config|
                data[rating_config[0]] &&
                  (rating_config[1].nil? || data[rating_config[0]].to_f >= rating_config[1]) &&
                  (rating_config[2].nil? || data[rating_config[0]].to_f <= rating_config[2])
              }.map do |rating_config|
                {
                  'name' => I18n.t(translation_key_prefix + rating_config[0], default: rating_config[0]),
                  'rating_value' => data[rating_config[0]]
                  # 'worst_rating' => rating_config[1],
                  # 'best_rating' => rating_config[2]
                }
              end
            }
          )
        end
      end
    end
  end
end
